function [medium] = create_water_medium(Nx, Ny, Nz, temp, aWater, y_water)
medium.density = waterDensity(temp) * ones(Nx, Ny, Nz); % Water density
medium.sound_speed = waterSoundSpeed(temp) * ones(Nx, Ny, Nz); % Water sound speed
medium.alpha_coeff = aWater * ones(Nx, Ny, Nz); % Water attenuation coefficient
medium.alpha_power = y_water; % Water power law exponent
end
