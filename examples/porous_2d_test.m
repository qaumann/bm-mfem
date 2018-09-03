%% Clasical
clc;
clear all;

model = FemModel();

% Dimension of the structure
Lx=2;
Ly=1;

% Number of elements in specific directions
nx=20;
ny=10;

% Calculation of the dimension of the elements (defined via L and n)
dx=Lx/nx;
dy=Ly/ny;

numnodes=(nx + 1)*(ny + 1);
numele=nx*ny;

% Generation of nodes
id=0;

for j=1:(ny + 1)
    for i=1:(nx + 1)
        id=id+1;
        model.addNewNode(id,(i-1)*dx,(j-1)*dy);
    end
end

% Assignment DOFs
model.getAllNodes.addDof({'DISPLACEMENT_SOLID_X', 'DISPLACEMENT_SOLID_Y', 'DISPLACEMENT_FLUID_X', 'DISPLACEMENT_FLUID_Y'});

% Generation of elements
id = 0;


for j=1:ny
    for i=1:nx
        id=id+1;
        a = i + (j-1)*(nx+1);
        model.addNewElement('ClassicalPorousElement2d4n',id,[a, a+1, a+1+(nx+1), a+(nx+1)]);
    end
end

% assignment of material properties
model.getAllElements.setPropertyValue('DENSITY_SOLID',30);
model.getAllElements.setPropertyValue('LAMBDA_SOLID',905357);
model.getAllElements.setPropertyValue('MUE_SOLID',264062);
model.getAllElements.setPropertyValue('DAMPING_SOLID',0);

model.getAllElements.setPropertyValue('DENSITY_FLUID',1.21);
model.getAllElements.setPropertyValue('VISCOSITY_FLUID',1.84e-5);
model.getAllElements.setPropertyValue('STANDARD_PRESSURE_FLUID',101);
model.getAllElements.setPropertyValue('HEAT_CAPACITY_FLUID',1.4);
model.getAllElements.setPropertyValue('PRANDTL_NUMBER_FLUID',0.71);

model.getAllElements.setPropertyValue('POROSITY',0.96);
model.getAllElements.setPropertyValue('TORTUOSITY',1.7);
model.getAllElements.setPropertyValue('FLOW_RESISTIVITY',32e3);
model.getAllElements.setPropertyValue('VISCOUS_LENGHT',90);
model.getAllElements.setPropertyValue('THERMAL_LENGTH',165);

model.getAllElements.setPropertyValue('FREQUENCY',510);
model.getAllElements.setPropertyValue('NUMBER_GAUSS_POINT',2);

% Definition of BCs
for i=1:(ny+1)
    model.getNode(1+(i-1)*(nx+1)).fixDof('DISPLACEMENT_SOLID_X');
    model.getNode(1+(i-1)*(nx+1)).fixDof('DISPLACEMENT_SOLID_Y');
    model.getNode(1+(i-1)*(nx+1)).fixDof('DISPLACEMENT_FLUID_X');
    model.getNode(1+(i-1)*(nx+1)).fixDof('DISPLACEMENT_FLUID_Y');
end

% Definition of loading
addPointLoadPorous(model.getNode(numnodes),1,[0 -1]);

% Determination of global matrices
assembling = SimpleAssembler(model);
[stiffnessMatrix, Kred] = assembling.assembleGlobalStiffnessMatrix(model);           
[massMatrix, Mred] = assembling.assembleGlobalMassMatrix(model);
  
% Solving
solver = SimpleHarmonicSolvingStrategy(model,510);
x = solver.solve();

step = 1;

VerschiebungDofs = model.getDofArray.getValue(step);

nodalForces = solver.getNodalForces(step);

v = Visualization(model);
v.setScaling(3e4);
v.plotUndeformed
v.plotDeformed
    
%% Total

clc;
clear all;

model = FemModel();

% Dimension of the structure
Lx=2;
Ly=1;

% Number of elements in specific directions
nx=20;
ny=10;

% Calculation of the dimension of the elements (defined via L and n)
dx=Lx/nx;
dy=Ly/ny;

numnodes=(nx + 1)*(ny + 1);
numele=nx*ny;

% Generation of nodes
id=0;

for j=1:(ny + 1)
    for i=1:(nx + 1)
        id=id+1;
        model.addNewNode(id,(i-1)*dx,(j-1)*dy);
    end
end

% Assignment DOFs
model.getAllNodes.addDof({'DISPLACEMENT_SOLID_X', 'DISPLACEMENT_SOLID_Y', 'DISPLACEMENT_TOTAL_X', 'DISPLACEMENT_TOTAL_Y'});

% Generation of elements
id = 0;


for j=1:ny
    for i=1:nx
        id=id+1;
        a = i + (j-1)*(nx+1);
        model.addNewElement('TotalPorousElement2d4n',id,[a, a+1, a+1+(nx+1), a+(nx+1)]);
    end
end
ff = 100;
% assignment of material properties
model.getAllElements.setPropertyValue('DENSITY_SOLID',30);
model.getAllElements.setPropertyValue('LAMBDA_SOLID',905357);
model.getAllElements.setPropertyValue('MUE_SOLID',264062);
model.getAllElements.setPropertyValue('DAMPING_SOLID',0);

model.getAllElements.setPropertyValue('DENSITY_FLUID',1.21);
model.getAllElements.setPropertyValue('VISCOSITY_FLUID',1.84e-5);
model.getAllElements.setPropertyValue('STANDARD_PRESSURE_FLUID',101);
model.getAllElements.setPropertyValue('HEAT_CAPACITY_FLUID',1.4);
model.getAllElements.setPropertyValue('PRANDTL_NUMBER_FLUID',0.71);

model.getAllElements.setPropertyValue('POROSITY',0.96);
model.getAllElements.setPropertyValue('TORTUOSITY',1.7);
model.getAllElements.setPropertyValue('FLOW_RESISTIVITY',32e3);
model.getAllElements.setPropertyValue('VISCOUS_LENGHT',90);
model.getAllElements.setPropertyValue('THERMAL_LENGTH',165);

model.getAllElements.setPropertyValue('FREQUENCY',ff);
model.getAllElements.setPropertyValue('NUMBER_GAUSS_POINT',2);

% Definition of BCs
for i=1:(ny+1)
    model.getNode(1+(i-1)*(nx+1)).fixDof('DISPLACEMENT_SOLID_X');
    model.getNode(1+(i-1)*(nx+1)).fixDof('DISPLACEMENT_SOLID_Y');
    model.getNode(1+(i-1)*(nx+1)).fixDof('DISPLACEMENT_TOTAL_X');
    model.getNode(1+(i-1)*(nx+1)).fixDof('DISPLACEMENT_TOTAL_Y');
end

% Definition of loading
addPointLoadPorous(model.getNode(numnodes),1,[0 -1]);

% Determination of global matrices
assembling = SimpleAssembler(model);
stiffnessMatrix = assembling.assembleGlobalStiffnessMatrix(model);           
massMatrix = assembling.assembleGlobalMassMatrix(model);

% Solving
solver = SimpleHarmonicSolvingStrategy(model,ff);
x = solver.solve();

step = 1;

VerschiebungDofs = model.getDofArray.getValue(step);

nodalForces = solver.getNodalForces(step);

% v = Visualization(model);
% v.setScaling(3e5);
% v.plotUndeformed
% v.plotDeformed
xx = model.getAllNodes.getX();
yy = model.getAllNodes.getY();
ux = model.getAllNodes.getDofValue('DISPLACEMENT_SOLID_X');
uy = model.getAllNodes.getDofValue('DISPLACEMENT_SOLID_Y');
scaling = 3e3;
% z = reshape(sqrt(angle(ux).^2+angle(uy).^2),21,11);
z = reshape(angle(ux),21,11);
% z = reshape(angle(uy),21,11);
xxx = reshape(xx+scaling*abs(ux.'),21,11);
yyy = reshape(yy+scaling*abs(uy.'),21,11);
figure()
subplot(2,1,1)
surf(xxx,yyy,z,'FaceColor','interp')
colorbar
view(0,90)

subplot(2,1,2)
uxf = model.getAllNodes.getDofValue('DISPLACEMENT_TOTAL_X');
uyf = model.getAllNodes.getDofValue('DISPLACEMENT_TOTAL_Y');
% zf = reshape(sqrt(angle(uxf).^2+angle(uyf).^2),21,11);
zf = reshape(angle(uxf),21,11);
% zf = reshape(angle(uyf),21,11);
xxxf = reshape(xx+scaling*abs(uxf.'),21,11);
yyyf = reshape(yy+scaling*abs(uyf.'),21,11);
surf(xxxf,yyyf,zf,'FaceColor','interp')
colorbar
view(0,90)
%% Mixed

clc;
clear all;

model = FemModel();

% Dimension of the structure
Lx=2;
Ly=1;

% Number of elements in specific directions
nx=20;
ny=10;

% Calculation of the dimension of the elements (defined via L and n)
dx=Lx/nx;
dy=Ly/ny;

numnodes=(nx + 1)*(ny + 1);
numele=nx*ny;

% Generation of nodes
id=0;

for j=1:(ny + 1)
    for i=1:(nx + 1)
        id=id+1;
        model.addNewNode(id,(i-1)*dx,(j-1)*dy);
    end
end

% Assignment DOFs
model.getAllNodes.addDof({'DISPLACEMENT_SOLID_X', 'DISPLACEMENT_SOLID_Y', 'PORE_PRESSURE'});

% Generation of elements
id = 0;


for j=1:ny
    for i=1:nx
        id=id+1;
        a = i + (j-1)*(nx+1);
        model.addNewElement('MixedPorousElement2d4n',id,[a, a+1, a+1+(nx+1), a+(nx+1)]);
    end
end

% assignment of material properties
model.getAllElements.setPropertyValue('DENSITY_SOLID',30);
model.getAllElements.setPropertyValue('LAMBDA_SOLID',905357);
model.getAllElements.setPropertyValue('MUE_SOLID',264062);
model.getAllElements.setPropertyValue('DAMPING_SOLID',0);

model.getAllElements.setPropertyValue('DENSITY_FLUID',1.21);
model.getAllElements.setPropertyValue('VISCOSITY_FLUID',1.84e-5);
model.getAllElements.setPropertyValue('STANDARD_PRESSURE_FLUID',101);
model.getAllElements.setPropertyValue('HEAT_CAPACITY_FLUID',1.4);
model.getAllElements.setPropertyValue('PRANDTL_NUMBER_FLUID',0.71);

model.getAllElements.setPropertyValue('POROSITY',0.96);
model.getAllElements.setPropertyValue('TORTUOSITY',1.7);
model.getAllElements.setPropertyValue('FLOW_RESISTIVITY',32e3);
model.getAllElements.setPropertyValue('VISCOUS_LENGHT',90);
model.getAllElements.setPropertyValue('THERMAL_LENGTH',165);

model.getAllElements.setPropertyValue('FREQUENCY',200);
model.getAllElements.setPropertyValue('NUMBER_GAUSS_POINT',2);

% Definition of BCs
for i=1:(ny+1)
    model.getNode(1+(i-1)*(nx+1)).fixDof('DISPLACEMENT_SOLID_X');
    model.getNode(1+(i-1)*(nx+1)).fixDof('DISPLACEMENT_SOLID_Y');
end

for i=1:(nx+1)
    model.getNode(i).fixDof('PORE_PRESSURE');
end

for i=1:(ny+1)
    model.getNode(i*(nx+1)).fixDof('PORE_PRESSURE');
end

a=(nx+1)*ny+1;
b=numnodes;
for i=a:b
    model.getNode(i).fixDof('PORE_PRESSURE');
end

% Definition of loading
addPointLoadPorous(model.getNode(numnodes),1,[0 -1]);

% Determination of global matrices
assembling = SimpleAssembler(model);
stiffnessMatrix = assembling.assembleGlobalStiffnessMatrix(model);           
massMatrix = assembling.assembleGlobalMassMatrix(model);

% Solving
solver = SimpleHarmonicSolvingStrategy(model,200);
x = solver.solve();

step = 1;

VerschiebungDofs = model.getDofArray.getValue(step);

nodalForces = solver.getNodalForces(step);

v = Visualization(model);
v.setScaling(3e4);
v.plotUndeformed
v.plotDeformed

%% Schnipsel
rea=real(VerschiebungDofs);
im=imag(VerschiebungDofs);
scatter(rea,im)
