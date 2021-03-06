classdef BeamElement3d2n < LinearElement
    %BEAMELEMENT3D2N Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        length0 %initial length
    end
    
    methods
        % constructor
        function obj = BeamElement3d2n(id, nodeArray)
            
            requiredPropertyNames = cellstr(["IY", "IZ", "IT", ...
                "YOUNGS_MODULUS", "POISSON_RATIO", "CROSS_SECTION", ...
                "DENSITY"]);
            
            if nargin == 0
                super_args = {};
            elseif nargin == 2
                if ~(length(nodeArray) == 2 && isa(nodeArray,'Node'))
                    error('problem with the nodes in element %d', id);
                end
                super_args = {id, nodeArray, requiredPropertyNames};
            end
            
            % call the super class constructor
            obj@LinearElement(super_args{:});
            obj.dofNames = cellstr(["DISPLACEMENT_X", "DISPLACEMENT_Y", "DISPLACEMENT_Z", ...
                "ROTATION_X", "ROTATION_Y", "ROTATION_Z"]);
        end
        
        function initialize(obj)
            obj.localSystem = obj.computeLocalSystem();
            obj.length0 = computeLength(obj.nodeArray(1).getCoords, ...
                obj.nodeArray(2).getCoords);
        end
        
        function stiffnessMatrix = computeLocalStiffnessMatrix(obj)
           E = obj.getPropertyValue('YOUNGS_MODULUS');
           nu = obj.getPropertyValue('POISSON_RATIO');
           G = E / (2 * (1-nu) );
           A = obj.getPropertyValue('CROSS_SECTION');
           Iy = obj.getPropertyValue('IY');
           Iz = obj.getPropertyValue('IZ');
           It = obj.getPropertyValue('IT');
           L = obj.length0;
           L2 = L*L;
           L3 = L2*L;
           
           stiffnessMatrix = sparse(12,12);
           
           stiffnessMatrix(1,1) = E*A / L;
           stiffnessMatrix(1,7) = - stiffnessMatrix(1,1);
           stiffnessMatrix(7,7) = stiffnessMatrix(1,1);
           stiffnessMatrix(7,1) = - stiffnessMatrix(1,1);
           
           EIz = E*Iz;
           stiffnessMatrix(2,2) = 12 * EIz / L3;
           stiffnessMatrix(2,8) = - stiffnessMatrix(2,2);
           stiffnessMatrix(8,8) = stiffnessMatrix(2,2);
           stiffnessMatrix(8,2) = - stiffnessMatrix(2,2);
           stiffnessMatrix(6,6) = 4 * EIz / L;
           stiffnessMatrix(12,12) = stiffnessMatrix(6,6);
           stiffnessMatrix(2,6) = 6 * EIz / L2;
           stiffnessMatrix(2,12) = stiffnessMatrix(2,6);
           stiffnessMatrix(6,2) = stiffnessMatrix(2,6);
           stiffnessMatrix(12,2) = stiffnessMatrix(2,6);
           stiffnessMatrix(6,8) = - stiffnessMatrix(2,6);
           stiffnessMatrix(8,6) = - stiffnessMatrix(2,6);
           stiffnessMatrix(8,12) = - stiffnessMatrix(2,6);
           stiffnessMatrix(12,8) = - stiffnessMatrix(2,6);
           stiffnessMatrix(6,12) = 2 * EIz / L;
           stiffnessMatrix(12,6) = stiffnessMatrix(6,12);
           
           EIy = E*Iy;
           stiffnessMatrix(3,3) = 12 * EIy / L3;
           stiffnessMatrix(3,9) = - stiffnessMatrix(3,3);
           stiffnessMatrix(9,9) = stiffnessMatrix(3,3);
           stiffnessMatrix(9,3) = - stiffnessMatrix(3,3);
           stiffnessMatrix(5,5) = 4 * EIy / L;
           stiffnessMatrix(11,11) = stiffnessMatrix(5,5);
           stiffnessMatrix(3,5) = - 6 * EIy / L2;
           stiffnessMatrix(3,11) = stiffnessMatrix(3,5);
           stiffnessMatrix(5,3) = stiffnessMatrix(3,5);
           stiffnessMatrix(11,3) = stiffnessMatrix(3,5);
           stiffnessMatrix(5,9) = - stiffnessMatrix(3,5);
           stiffnessMatrix(9,5) = - stiffnessMatrix(3,5);
           stiffnessMatrix(9,11) = - stiffnessMatrix(3,5);
           stiffnessMatrix(11,9) = - stiffnessMatrix(3,5);
           stiffnessMatrix(5,11) = 2 * EIy / L;
           stiffnessMatrix(11,5) = stiffnessMatrix(5,11);
           
           stiffnessMatrix(4,4) = G*It / L;
           stiffnessMatrix(10,10) = stiffnessMatrix(4,4);
           stiffnessMatrix(10,4) = - stiffnessMatrix(4,4);
           stiffnessMatrix(4,10) = - stiffnessMatrix(4,4);
           
           tMat = obj.getTransformationMatrix;
           stiffnessMatrix = tMat' * stiffnessMatrix * tMat;
        end
        
        function massMatrix = computeLocalMassMatrix(obj)
            A = obj.getPropertyValue('CROSS_SECTION');
            L = obj.length0;
            L2 = L*L;
            rho = obj.getPropertyValue('DENSITY');
            m = A * L * rho;
            Iy = obj.getPropertyValue('IY');
            Iz = obj.getPropertyValue('IZ');
            It = obj.getPropertyValue('IT');
            
            massMatrix = sparse(12,12);
            massMatrix(1,1) = m/3;
            massMatrix(7,7) = massMatrix(1,1);
            massMatrix(1,7) = m/6;
            massMatrix(7,1) = massMatrix(1,7);
            
            massMatrix(2,2) = m * (13/35 + 6*Iz/(5*A*L2));
            massMatrix(2,6) = m * (11*L/210 + Iz/(10*A*L));
            massMatrix(6,2) = massMatrix(2,6);
            massMatrix(2,8) = m * (9/70 - 6*Iz/(5*A*L2));
            massMatrix(8,2) = massMatrix(2,8);
            massMatrix(2,12) = m * (-13*L/420 + Iz/(10*A*L));
            massMatrix(12,2) = massMatrix(2,12);
            
            massMatrix(3,3) = m * (13/35 + 6*Iy/(5*A*L2));
            massMatrix(3,5) = m * (- 11*L/210 - Iy/(10*A*L));
            massMatrix(5,3) = massMatrix(3,5);
            massMatrix(3,9) = m * (9/70 - 6*Iy/(5*A*L2));
            massMatrix(9,3) = massMatrix(3,9);
            massMatrix(3,11) = m * (13*L/420 - Iy/(10*A*L));
            massMatrix(11,3) = massMatrix(3,11);
            
            massMatrix(4,4) = m * (It/(3*A));
            massMatrix(10,10) = massMatrix(4,4);
            massMatrix(4,10) = massMatrix(4,4) / 2;
            massMatrix(10,4) = massMatrix(4,10);
            
            massMatrix(5,5) = m * (L2/105 + 2*Iy/(15*A));
            massMatrix(5,9) = m * (-13*L/420 + Iy/(10*A*L));
            massMatrix(9,5) = massMatrix(5,9);
            massMatrix(5,11) = m * (-L2/140 - Iy/(30*A));
            massMatrix(11,5) = massMatrix(5,11);
            
            massMatrix(6,6) = m * (L2/105 + 2*Iz/(15*A));
            massMatrix(6,8) = m * (13*L/420 - Iz/(10*A*L));
            massMatrix(8,6) = massMatrix(6,8);
            massMatrix(6,12) = m * (-L2/140 - Iz/(30*A));
            massMatrix(12,6) = massMatrix(6,12);
            
            massMatrix(8,8) = massMatrix(2,2);
            massMatrix(8,12) = - massMatrix(2,6);
            massMatrix(12,8) = massMatrix(8,12);
            
            massMatrix(9,9) = massMatrix(3,3);
            massMatrix(9,11) = - massMatrix(3,5);
            massMatrix(11,9) = massMatrix(9,11);
            
            massMatrix(11,11) = massMatrix(5,5);
            massMatrix(12,12) = massMatrix(6,6);
            
            tMat = obj.getTransformationMatrix;
            massMatrix = tMat' * massMatrix * tMat;
            
            %simple lumping
%             lMass = 0.5 * A * L * rho;
%             massMatrix = sparse(12,12);
%             
%             massMatrix(1,1) = lMass;
%             massMatrix(2,2) = lMass;
%             massMatrix(3,3) = lMass;
% %             massMatrix(4,4) = lMass;
% %             massMatrix(5,5) = lMass;
% %             massMatrix(6,6) = lMass;
%             massMatrix(7,7) = lMass;
%             massMatrix(8,8) = lMass;
%             massMatrix(9,9) = lMass;
% %             massMatrix(10,10) = lMass;
% %             massMatrix(11,11) = lMass;
% %             massMatrix(12,12) = lMass;
%             tMat = element.getTransformationMatrix;
%             massMatrix = tMat' * massMatrix * tMat;
        end
        
        function dampingMatrix = computeLocalDampingMatrix(obj)
            eProperties = obj.getProperties;
            if (eProperties.hasValue('RAYLEIGH_ALPHA')) ...
                    && (eProperties.hasValue('RAYLEIGH_BETA'))
                dampingMatrix = eProperties.getValue('RAYLEIGH_ALPHA') * obj.computeLocalMassMatrix ...
                    + eProperties.getValue('RAYLEIGH_BETA') * obj.computeLocalStiffnessMatrix;
            else
                dampingMatrix = sparse(12,12);
            end          
        end
        
        function forceVector = computeLocalForceVector(obj)
           forceVector = sparse(1,12);
%            disp = element.getValuesVector('end');
%            forceVector = element.computeLocalStiffnessMatrix() * disp';
%            forceVector = forceVector';
        end
        
        function dofs = getDofList(obj)
            dofs([1 7]) = obj.nodeArray.getDof('DISPLACEMENT_X');
            dofs([2 8]) = obj.nodeArray.getDof('DISPLACEMENT_Y'); 
            dofs([3 9]) = obj.nodeArray.getDof('DISPLACEMENT_Z');
            
            dofs([4 10]) = obj.nodeArray.getDof('ROTATION_X');
            dofs([5 11]) = obj.nodeArray.getDof('ROTATION_Y'); 
            dofs([6 12]) = obj.nodeArray.getDof('ROTATION_Z');
        end
        
        function vals = getValuesVector(obj, step)
            vals = zeros(1,12);
            
            vals([1 7]) = obj.nodeArray.getDofValue('DISPLACEMENT_X',step);
            vals([2 8]) = obj.nodeArray.getDofValue('DISPLACEMENT_Y',step);
            vals([3 9]) = obj.nodeArray.getDofValue('DISPLACEMENT_Z',step);
            
            vals([4 10]) = obj.nodeArray.getDofValue('ROTATION_X',step);
            vals([5 11]) = obj.nodeArray.getDofValue('ROTATION_Y',step);
            vals([6 12]) = obj.nodeArray.getDofValue('ROTATION_Z',step);
        end
        
        function vals = getFirstDerivativesVector(obj, step)
            vals = zeros(1,12);
            
            [~, vals([1 7]), ~] = obj.nodeArray.getDof('DISPLACEMENT_X').getAllValues(step);
            [~, vals([2 8]), ~] = obj.nodeArray.getDof('DISPLACEMENT_Y').getAllValues(step);
            [~, vals([3 9]), ~] = obj.nodeArray.getDof('DISPLACEMENT_Z').getAllValues(step);
            
            [~, vals([4 10]), ~] = obj.nodeArray.getDof('ROTATION_X').getAllValues(step);
            [~, vals([5 11]), ~] = obj.nodeArray.getDof('ROTATION_Y').getAllValues(step);
            [~, vals([6 12]), ~] = obj.nodeArray.getDof('ROTATION_Z').getAllValues(step);
        end
        
        function vals = getSecondDerivativesVector(obj, step)
            vals = zeros(1,12);            
            
            [~, ~, vals([1 7])] = obj.nodeArray.getDof('DISPLACEMENT_X').getAllValues(step);
            [~, ~, vals([2 8])] = obj.nodeArray.getDof('DISPLACEMENT_Y').getAllValues(step);
            [~, ~, vals([3 9])] = obj.nodeArray.getDof('DISPLACEMENT_Z').getAllValues(step);
            
            [~, ~, vals([4 10])] = obj.nodeArray.getDof('ROTATION_X').getAllValues(step);
            [~, ~, vals([5 11])] = obj.nodeArray.getDof('ROTATION_Y').getAllValues(step);
            [~, ~, vals([6 12])] = obj.nodeArray.getDof('ROTATION_Z').getAllValues(step);
        end
        
        function update(obj)
            obj.length0 = computeLength(obj.nodeArray(1).getCoords, ...
                    obj.nodeArray(2).getCoords);
        end
        
    end
    
end

