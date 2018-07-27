clear;

node01 = Node(1,0,0);
node02 = Node(2,2,0);
node03 = Node(3,4,0);
node04 = Node(4,6,0);
node05 = Node(5,0,1);
node06 = Node(6,2,1);
node07 = Node(7,4,1);
node08 = Node(8,6,1);
node09 = Node(9,0,2);
node10 = Node(10,2,2);
node11 = Node(11,4,2);
node12 = Node(12,6,2);

nodeArray = [node01 node02 node03 node04 node05 ...
    node06 node07 node08 node09 node10 node11 node12];

nodeArray.addDof({'DISPLACEMENT_X', 'DISPLACEMENT_Y'});


ele01 = QuadrilateralElement2d4n(1,[node01 node02 node06 node05]);
ele02 = QuadrilateralElement2d4n(2,[node02 node03 node07 node06]);
ele03 = QuadrilateralElement2d4n(3,[node03 node04 node08 node07]);
ele04 = QuadrilateralElement2d4n(4,[node05 node06 node10 node09]);
ele05 = QuadrilateralElement2d4n(5,[node06 node07 node11 node10]);
ele06 = QuadrilateralElement2d4n(6,[node07 node08 node12 node11]);




elementArray = [ele01 ele02 ele03 ele04 ele05 ele06];

elementArray.setPropertyValue('YOUNGS_MODULUS',96);
elementArray.setPropertyValue('POISSON_RATIO',1/3);
elementArray.setPropertyValue('NUMBER_GAUSS_POINT',2);
elementArray.setPropertyValue('DENSITY',7860);


model = FemModel(nodeArray, elementArray);

solver = BlochInverse1D(model);
assembling = SimpleAssembler(model);

stiffnessMatrix = assembling.assembleGlobalStiffnessMatrix(model);
            
massMatrix = assembling.assembleGlobalMassMatrix(model);


initialize(solver)


[Kred,Mred] = reducedStiffnesAndMass (stiffnessMatrix,massMatrix,solver);  
Ktest = Kred{5,1};
Mtest = Mred{5,1};

omega_test = solver.calcOmega(Ktest,Mtest);
omega = cell(10000,1);
f=zeros(1,10000);
f_2=zeros(1,10000);
f_3=zeros(1,10000);
f_4=zeros(1,10000);
f_5=zeros(1,10000);

for i = 1:10000
    omega{i,1} = solver.calcOmega(Kred{i,1},Mred{i,1});
    f(i) = omega{i,1}(1,1)/(2*pi);
    f_2(i) = omega{i,1}(2,1)/(2*pi);
    f_3(i) = omega{i,1}(3,1)/(2*pi);
    f_4(i) = omega{i,1}(4,1)/(2*pi);
    f_5(i) = omega{i,1}(5,1)/(2*pi);
end


[kx,miu] = propConst(solver,10000);

figure(1);
plot(kx,f,kx,f_2)
title('Dispersion curves')
xlabel('Wavenumber k')
ylabel('frequenzy f')
xlim([0 pi])
legend({'1stBand','2ndBand'},'Location','EastOutside')




% figure(3);
% plot(kx,f_3,'b.')
% figure(4);
% plot(kx,f_4,'b.')
% figure(5);
% plot(kx,f_5,'b.')

