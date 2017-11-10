function [ type ] = checkPropertyName( name )
%CHECKVARIABLE Checks, if a variable name is valid
%   All variables which should be used in the program have to be defined
%   here.

type = 'undefined';

availableProperties = cellstr(["ELEMENTAL_STIFFNESS", ...
    "ELEMENTAL_DAMPING", ...
    "ELEMENTAL_MASS", ...
    "IY", ...
    "IZ", ...
    "IT", ...
    "YOUNGS_MODULUS", ...
    "SHEAR_MODULUS", ...
    "CROSS_SECTION", ...
    "DENSITY"]);

available3dProperties = cellstr(["VELOCITY", ...
    "ACCELERATION", ...
    "VOLUME_ACCELERATION"]);

if any(ismember(name, availableProperties))
    type = 'variable1d';
elseif any(ismember(name, available3dProperties))
    type = 'variable3d';
else
    error('A property with name \"%s\" has not been defined', name);
end

end

