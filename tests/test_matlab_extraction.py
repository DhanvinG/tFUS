"""Static preservation checks; these do not execute MATLAB or k-Wave."""
from pathlib import Path
import re
import textwrap
import unittest
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def normalized(text):
    return '\n'.join(line.rstrip() for line in text.splitlines()).strip()


def extracted_code():
    with zipfile.ZipFile(ROOT/'generateDatasetCurrent.mlx') as archive:
        root = ET.fromstring(archive.read('matlab/document.xml'))
    ns = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    code = []
    for paragraph in root.findall('.//w:p', ns):
        style = paragraph.find('w:pPr/w:pStyle', ns)
        if style is not None and style.get('{'+ns['w']+'}val') == 'code':
            code.append(''.join(paragraph.itertext()))
    return '\n'.join(code).replace('\r\n','\n')


class Extraction(unittest.TestCase):
    def test_readable_baseline_is_complete(self):
        redacted = re.sub(r"C:\\Users\\[^']*?\\tFUS", '<PATIENT_DATA_ROOT>', extracted_code())
        self.assertEqual(redacted, (ROOT/'docs/baseline.m').read_text(encoding='utf-8'))

    def test_all_twenty_helpers_preserved(self):
        baseline = extracted_code()
        starts = list(re.finditer(r'^\s*function ', baseline, re.M))
        self.assertEqual(len(starts),20)
        for i, match in enumerate(starts):
            stop = starts[i+1].start() if i+1 < len(starts) else baseline.index('    prev = pwd;')
            block = baseline[match.start():stop]
            last = list(re.finditer(r'^\s*end\s*$', block, re.M))[-1].end()
            block = textwrap.dedent(block[:last]).strip()+'\n'
            signature = re.search(r'function\s+(?:\[[^]]*\]|\w+)\s*=\s*(\w+)|function\s+(\w+)\(',block)
            name = next(x for x in signature.groups() if x)
            if name == 'DicomToVolume':
                block = block.replace('dicomread(filenumber)', 'dicomread(fullfile(dicom_folder, filenumber))').replace('dicominfo(filenumber)', 'dicominfo(fullfile(dicom_folder, filenumber))')
            with self.subTest(function=name):
                self.assertEqual(normalized(block), normalized((ROOT/f'matlab/functions/{name}.m').read_text(encoding='utf-8')))

    def test_simulation_export_body_preserved(self):
        baseline = extracted_code()
        body = baseline[baseline.index('    for poseIdx = 1:nPoses'):]
        body = body.replace("base = 'data/test';", "base = fullfile(cfg.output_dir, 'data', 'test');").replace("base = 'data/train';", "base = fullfile(cfg.output_dir, 'data', 'train');")
        body = body.replace('    for poseIdx = 1:nPoses', "    for poseIdx = 1:nPoses\n    fprintf('Simulating pose %d/%d\\n', poseIdx, nPoses);")
        self.assertEqual(normalized(body), normalized((ROOT/'matlab/stages/simulate_poses.m').read_text(encoding='utf-8')))

    def test_pose_math_preserved(self):
        baseline = extracted_code()
        start = baseline.index('    % Define transducer properties')
        end = baseline.index('    % create train/test directories once', start)
        body = baseline[start:end].replace('p0 = [165,240,229];','p0 = cfg.target_point_vox;')
        new = (ROOT/'matlab/stages/build_poses.m').read_text(encoding='utf-8')
        self.assertEqual(normalized(body),normalized(new[new.index('    % Define transducer properties'):]))


if __name__ == '__main__':
    unittest.main()
