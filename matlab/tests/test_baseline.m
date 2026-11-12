function tests = test_baseline
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'functions'));
testCase.TestData.root = root;
end

function testFOV(testCase)
ct = reshape(1:64, [4,4,4]);
[skull, result] = PutIntoFOV(ct, ct, [5,5,5], .625);
verifyEqual(testCase, result(2:5,2:5,2:5), ct);
verifyEqual(testCase, skull, result);
end

function testGridGuard(testCase)
validate_baseline_grid(zeros(4,4,4), zeros(4,4,4), [5,5,5], .625);
failed = false;
try
    validate_baseline_grid(zeros(3,4,4), zeros(3,4,4), [5,5,5], .625);
catch
    failed = true;
end
verifyTrue(testCase, failed);
end

function testRotation(testCase)
R = rotation_matrix_from_vectors([0 0 1], [1 0 0]);
verifyEqual(testCase, R*[0;0;1], [1;0;0], 'AbsTol', 1e-12);
verifyEqual(testCase, R'*R, eye(3), 'AbsTol', 1e-12);
end

function testCrop(testCase)
assumeTrue(testCase, exist('regionprops3','file') ~= 0);
volume = false(40,40,40); volume(15:20,15:20,15:20)=true;
[a,b,c,d,origin,target] = CutSimArea(volume,volume,volume,volume,volume);
verifySize(testCase,a,[172,172,300]);
verifyEqual(testCase,a,b); verifyEqual(testCase,a,c);
verifyEqual(testCase,a,d); verifyEqual(testCase,a,target);
verifySize(testCase,origin,[1,3]);
end
