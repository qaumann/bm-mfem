classdef SpringDamperElement3d2n < LinearElement
    %SPRINGDAMPERELEMENT3D2N Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (Access = private)
        length0 %initial length
    end
    
    methods
        % constructor
        function springDamperElement = SpringDamperElement3d2n(id, nodeArray)
            if nargin == 0
                super_args = {};
            elseif nargin == 2
                super_args = {id};
            end
            
            % call the super class constructor
            springDamperElement@LinearElement(super_args{:});
            springDamperElement.dofNames = cellstr(['DISPLACEMENT_X'; 'DISPLACEMENT_Y'; 'DISPLACEMENT_Z']);
            springDamperElement.requiredProperties = cellstr(["ELEMENTAL_STIFFNESS", "ELEMENTAL_DAMPING"]);
            springDamperElement.required3dProperties = [ ];
            
            % the constructor
            if nargin > 0
                if (length(nodeArray) == 2 && isa(nodeArray,'Node'))
                    springDamperElement.nodeArray = nodeArray;
                else
                    error('problem with the nodes in element %d', id);
                end
                
                springDamperElement.length0 = computeLength(springDamperElement.nodeArray(1).getCoords, ...
                    springDamperElement.nodeArray(2).getCoords);
            end
            
        end
        
        function stiffnessMatrix = OLDcomputeLocalStiffnessMatrix(springDamperElement)
           stiffness = springDamperElement.getPropertyValue('ELEMENTAL_STIFFNESS');
           stiffnessMatrix = zeros(6);
           for ii = 1:size(stiffnessMatrix,1)/2
               stiffnessMatrix(ii, ii) = stiffness(ii);
               stiffnessMatrix(ii+3, ii+3) = stiffness(ii);
               stiffnessMatrix(ii, ii+3) = -stiffness(ii);
               stiffnessMatrix(ii+3, ii) = -stiffness(ii);
           end
        end
        
        function stiffnessMatrix = computeLocalStiffnessMatrix(element)
           stiffness = element.getPropertyValue('ELEMENTAL_STIFFNESS');
           stiffnessMatrix = zeros(6);
           stiffnessMatrix(1,1) = stiffness;
           stiffnessMatrix(1,4) = - stiffness;
           stiffnessMatrix(4,4) = stiffness;
           stiffnessMatrix(4,1) = - stiffness;
           
           tMat = element.getTransformationMatrix;
           stiffnessMatrix = tMat' * stiffnessMatrix * tMat;
        end
        
        function massMatrix = computeLocalMassMatrix(element)
            massMatrix = zeros(6);
        end
        
        function dampingMatrix = computeLocalDampingMatrix(element)
           damping = element.getPropertyValue('ELEMENTAL_DAMPING');
           dampingMatrix = zeros(6);
           dampingMatrix(1,1) = damping;
           dampingMatrix(1,4) = - damping;
           dampingMatrix(4,4) = damping;
           dampingMatrix(4,1) = - damping;
           
           tMat = element.getTransformationMatrix;
           dampingMatrix = tMat' * dampingMatrix * tMat;           
        end
        
        function forceVector = computeLocalForceVector(element)
           forceVector = zeros(1,6);
%            stiffness = element.getPropertyValue('ELEMENTAL_STIFFNESS');
%            nodes = element.getNodes;
%            
%            tMat = element.getTransformationMatrix;
%            
%            disp = zeros(1,3);
%            disp(1) = nodes(2).getDofValue('DISPLACEMENT_X','end') - nodes(1).getDofValue('DISPLACEMENT_X','end');
%            disp(2) = nodes(2).getDofValue('DISPLACEMENT_Y','end') - nodes(1).getDofValue('DISPLACEMENT_Y','end');
%            disp(3) = nodes(2).getDofValue('DISPLACEMENT_Z','end') - nodes(1).getDofValue('DISPLACEMENT_Z','end');
%            localDisp = tMat(1:3,1:3)' * disp';
%            
%            forceVector(1) = - stiffness * localDisp(1);
%            forceVector(4) = stiffness * localDisp(1);
%            
%            forceVector = tMat' * forceVector';
%            forceVector = forceVector';
        end        
        
        function update(springDamperElement)
            springDamperElement.length0 = computeLength(springDamperElement.nodeArray(1).getCoords, ...
                    springDamperElement.nodeArray(2).getCoords);
        end
        
    end
    
    methods (Access = private)
       
        function tMat = getTransformationMatrix(ele)
            dirX = ele.nodeArray(2).getCoords - ele.nodeArray(1).getCoords;
            dirX = dirX ./ norm(dirX);
            
            dirY = cross([0 0 1], dirX);
            dirY = dirY ./ norm(dirY);
            dirZ = cross(dirX, dirY);
            dirZ = dirZ ./ norm(dirZ);
            
            T=zeros(3);         % the scalar product is applied implicitly here
            T(1,:) = dirX;
            T(2,:) = dirY;
            T(3,:) = dirZ;
           
            tMat = zeros(6);
            tMat(1:3,1:3) = T;
            tMat(4:6,4:6) = T;
        end
        
    end
    
end
