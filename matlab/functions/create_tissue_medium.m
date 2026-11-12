function [medium] = create_tissue_medium(Nx, Ny, Nz, density, sound_speed, alpha_coeff, y)
medium.density = density; % Tissue density
medium.sound_speed = sound_speed; % Tissue sound speed
medium.alpha_coeff = alpha_coeff; % Tissue attenuation coefficient
medium.alpha_power = y; % Tissue power law exponent
end
