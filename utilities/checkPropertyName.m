function [ type ] = checkPropertyName( name )
%CHECKVARIABLE Checks, if a variable name is valid
%   All variables which should be used in the program have to be defined
%   here.

availableProperties = ["ELEMENTAL_STIFFNESS", ...
    "ELEMENTAL_DAMPING", ...
    "ELEMENTAL_MASS", ...
    "IY", ...
    "IZ", ...
    "IT", ...
    "YOUNGS_MODULUS", ...
    "POISSON_RATIO", ...
    "CROSS_SECTION", ...
    "THICKNESS", ...
    "NUMBER_GAUSS_POINT", ... 
    "SHEAR_CORRECTION_FACTOR",...
    "DENSITY", ...
    "STEP", ...
    "RAYLEIGH_ALPHA", ...
    "RAYLEIGH_BETA", ...
    "FRAME_DENSITY", ...
    "FRAME_LAME_PARAMETER_LAMBDA", ...
    "FRAME_LAME_PARAMETER_MU", ...
    "AMBIENT_FLUID_DENSITY", ...
    "AMBIENT_FLUID_VISCOSITY", ...
    "AMBIENT_FLUID_STANDARD_PRESSURE",...
    "HEAT_CAPACITY_RATIO",...
    "PRANDTL_NUMBER",...
    "POROSITY",...
    "TORTUOSITY", ...
    "STATIC_FLOW_RESISTIVITY",...
    "VISCOUS_CHAR_LENGTH",...
    "THERMAL_CHAR_LENGTH",...
    "FREQUENCY"];

available3dProperties = ["VOLUME_ACCELERATION"];

availableFlags = ["FULL_INTEGRATION", ...
    "USE_CONSISTENT_MASS_MATRIX"];

if any(ismember(name, availableProperties))
    type = 'variable1d';
elseif any(ismember(name, available3dProperties))
    type = 'variable3d';
elseif any(ismember(name, availableFlags))
    type = 'flag';
else
    msg = ['CheckPropertyName: A property with name \"', ...
        name, '\" is not defined'];
    e = MException('MATLAB:bm_mfem:undefinedPropertyName',msg);
    throw(e);
end

end

