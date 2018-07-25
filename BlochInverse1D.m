classdef BlochInverse1D < Solver
    
    properties (Access = private)
        femModel
        assembler
        isInitialized
        
        stiffnessMatrix
        massMatrix    
        
        leftDofs
        rightDofs
        leftNodes
        rightNodes     
    end
    
    methods
        function obj = BlochInverse1D(femModel)
            if nargin > 0 
                obj.femModel = femModel;
                obj.assembler = SimpleAssembler(femModel);
                obj.isInitialized = false;
            else
                error('Error (BlochInverse1D): no fem model defined!')
            end        
%             obj.leftNodes = obj.findLeftNodes();
%             
%             obj.rightNodes = obj.findRightNodes();
        end 
        
        function solve(obj, ~)
            if ~ obj.isInitialized
                obj.initialize();
            end            
            %rest von solve fehlt (mit Blochtheorem)
            
            
        end
       
        
        function [nodeIdsLeft] = findLeftNodes(obj)
           
            nodeArray = obj.femModel.getAllNodes;
            nodeIds = arrayfun(@(node) node.getId, nodeArray);
            nodeXcoords = arrayfun(@(node) node.getX, nodeArray);
           
            sortedX = sort(nodeXcoords);
            minX = sortedX(1);       
            n=0;         
            for i=1:length(nodeXcoords)
                if nodeXcoords(i) == minX
                    n = n+1;
                    nodeIdsLeft(n) = nodeIds(i);        
                    
%                    
                    
                end
            end
            fprintf('Number of left boundary nodes is %s. \n', num2str(n))
            %obj.leftNodes = nodeIdsLeft;    %anstatt  obj.leftNodes(n) = nodeIds(i);
        end
            
       function [nodeIdsRight] = findRightNodes(obj) 
             
            nodeArray = obj.femModel.getAllNodes;
            nodeIds = arrayfun(@(node) node.getId, nodeArray);
            nodeXcoords = arrayfun(@(node) node.getX, nodeArray);
            sortedX = sort(nodeXcoords);
 
            maxX = sortedX(length(sortedX));
            n=0;         
            for i=1:length(nodeXcoords)
                if nodeXcoords(i) == maxX
                    n = n+1;
                    nodeIdsRight(n) = nodeIds(i);                     
                end
            end
%          
            fprintf('Number of right boundary nodes is %s. \n', num2str(n))
       end
             
            
       function [leftDofs,rightDofs] = getLeftRightDofIds(obj)  %right and left nodes are requiered
            nodeArray = obj.femModel.getAllNodes;
            nodeIdsRight = obj.rightNodes;
            nodeIdsLeft = obj.leftNodes;      

            dofArray1 = arrayfun(@(node) node.getDofArray, nodeArray, 'UniformOutput', false)';  %dof Array1=[(2Spaltex1Zeile);(2x1);(2x1)...],  2=x und y FG
            %a=dofArray1{2,1}(1,2) works here        
             dofArray = [dofArray1{:}];   %dofArray=[1x1 1x1 1x1] (mit doppelter L�nge, da x und y jew eigene Eintr�ge haben)
%             femModel.dofArray = reshape(femModel.dofArray,1,size(femModel.dofArray,1)*size(femModel.dofArray,2));
            for ii = 1:length(dofArray)
                dofArray(ii).setId(ii);
            end           

            n = length(dofArray1{1,1});
            fprintf('%s degrees of freedom',num2str(n))
            leftDofs = zeros(1,length(nodeIdsLeft)*n);
            rightDofs = zeros(1,length(nodeIdsRight)*n);
            x=0;
            for i=1:(length(nodeIdsLeft))
                for j=1:n
                    x=x+1;
                    leftDofs(x) = getId(dofArray(nodeIdsLeft(i)*n-n+j));
                    rightDofs(x) = getId(dofArray(nodeIdsRight(i)*n-n+j));
                end
            end
                                        
       end
       
       
       function [kx,miu] = propConst(obj,numberOfWaveNumbers) %obj kann auch entfernt werden -> dann muss die Funktion aber statisch sein!
           kx = linspace(1e-6,pi,numberOfWaveNumbers);    %15 ist viel zu wenig
           miu = exp(i*kx);
       end
           
        
       function R = transformationMatrix(obj,miu,index)
           nodeIdsRight = obj.rightNodes;
           nodeIdsLeft = obj.leftNodes; 
           leftDofs = obj.leftDofs;
           rightDofs = obj.rightDofs;
           M = obj.massMatrix;
           R = [eye(length(leftDofs)), zeros(length(leftDofs),length(M)-2*length(leftDofs)); ...
               zeros(length(M)-2*length(leftDofs),length(leftDofs)), eye(length(M)-2*length(leftDofs));...
               miu(index)*eye(length(leftDofs)), zeros(length(leftDofs),length(M)-2*length(leftDofs))];
       end          
     
       function [Kred,Mred] = reducedStiffnesAndMass (K,M,obj)
           numberOfWaveNumbers = 100;
            
           [kx,miu] = propConst(obj,numberOfWaveNumbers);
            Kred = cell(numberOfWaveNumbers,1);
            Mred = cell(numberOfWaveNumbers,1);
            
            
            for i=1:numberOfWaveNumbers
            R = transformationMatrix(obj,miu,i);    
            Kred{i,1} = conj(R)'*K*R;
            Mred{i,1} = conj(R)'*M*R;
            end
       end
       
        function initialize(obj)
            if ~ obj.femModel.isInitialized()
                obj.femModel.initialize;
            end
                       
            % assemble and reduce matrices
            obj.massMatrix = obj.assembler.assembleGlobalMassMatrix(obj.femModel);
            obj.stiffnessMatrix = obj.assembler.assembleGlobalStiffnessMatrix(obj.femModel);
            
            
            %nodeArray = obj.femModel.getAllNodes; 
            %momentan auch in"findright/left Nodes/Dofs"
            
            nodeIdsLeft = obj.findLeftNodes;            
            %nodeIdsRight = findRightNodes(obj);
            nodeIdsRight = obj.findRightNodes;
            
            obj.leftNodes = nodeIdsLeft; %auch in Funktionen m�glich
            obj.rightNodes = nodeIdsRight;
            
            leftNodes = getNodes(obj.femModel, nodeIdsLeft); 
            rightNodes = getNodes(obj.femModel, nodeIdsRight);

            leftNodeX = getX(leftNodes);
            leftNodeY = getY(leftNodes);
            rightNodeX = getX(rightNodes);
            rightNodeY = getY(rightNodes);
            
            
            disp('left Nodes: [id,x,y]')
            X=[nodeIdsLeft.' leftNodeX.' leftNodeY.'];
            disp(X)
            
            disp('right Nodes: [id,x,y]')
            Y=[nodeIdsRight.' rightNodeX.' rightNodeY.'];
            disp(Y)
            
            
            [leftDofs,rightDofs] = getLeftRightDofIds(obj);
%             [leftDofs2,rightDofs2] = obj.getLeftRightDofIds
                        
            obj.leftDofs = leftDofs;
            obj.rightDofs = rightDofs;
            
            
            
            if length(nodeIdsLeft) ~= length(nodeIdsRight)
                error('Same amount of left and right boundary nodes are requiered')
            end
            
            for i = 1:length(leftNodeY)
                if leftNodeY(i) ~= rightNodeY(i)
                    error('corresponding boundary nodes must have the same y-coordinates')
                end
            end
            
            for i = 1:length(leftNodeX)
                if leftNodeX(1) ~= leftNodeX(i)
                    error('All left boundary nodes must have the same x-coordinates')
                end
                if rightNodeX(1) ~= rightNodeX(i)
                    error('All right boundary nodes must have the same x-coordinates')
                end
            end
                


        end %end initialize
        
        
      
        
      
        
      %             dofIds = Dof.getId;      %%%oder femModel.getId? erst mit femModel "objekt erstellen" zb femmodel.getarray
%             %nodeIds = Node.getId;    nur von 1 Knoten
%             %nodeCoords = node.getCoords   nur von 1 Knoten...
%             x = Node.getX;
%             y = Node.getY;
%             ysorted=sort(y);
%             xsorted=sort(x);
%             b=1;
%             while xsorted(1)==xsorted(b)
%                 b=b+1; %count the amount of same x-Coordinates/number of rows
%             end
%             a=zeros(1,b);
%             for i=1:b
%                 a(i)=1;
%                 x=1;
%                 while ysorted((i-1)*x+1) == ysorted(a(i))
%                     a(i)=a(i)+1;   
%                 end
%                 %a(i)= Anzahl gleicher y-Werte mit Koordinate x(i)
%                 x = a(1); 
%                 if a(1)~=a(i) %for every x=f, there is the same amount of nodes 
%                                 %with the same y-Coordinates
%                     disp('y-Coordinates in every row have to be equal')
%                 end
%                     
%             end
%             
%             
            
            %             nodes = femModel.getAllNodes;
%             a=2;
%             while nodes(3,1) == nodes(3,a) %Compare y-Coordinates of first row
%                 a=a+1;
%             end
%             n=a-1; %length of the beam
% 
%             a=1;
%             while nodes(2,1) == nodes(2,1+a*n) 
%                 %Compare x-Coordinates of first column
% 
%                 a=a+1;
%                 if size(nodes,2) < 1+a*n
%                     break
%                 end
%                 
%             end
%             m=a; %length (in y-direction) of the beam
% 
%             
%        
%             for i=1:m            
%                 x=1+n*(i-1);    %left node ID
%                 for j=1:n
% 
%                     if nodes(3,x)==nodes(3,x+j-1)
%                     else
%                         disp('y-Coordinates in the same row have to be equal')
%                     end 
%                 end
%           end
        
    end %end methods
    
    methods (Static)
        
       function omega = calcOmega(Kred,Mred)
           omega2 = eigs(Kred,Mred,5,'sm');
           omega = sqrt(abs(omega2));          
       end
       
    end
    
end