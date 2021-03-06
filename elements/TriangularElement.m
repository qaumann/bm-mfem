classdef TriangularElement < Element
    %TRIANGULARELEMENT Base class for quadraliteral elements
    %   Detailed explanation goes here
    
    properties (Access = protected)
    end
    
    methods
        % Constructor
        function triangularElement = TriangularElement(id, nodeArray, requiredProperties)
            if nargin == 0
                super_args = {};
            elseif nargin == 3
                super_args = {id, nodeArray, requiredProperties};
            end
            
            triangularElement@Element(super_args{:});
        end

        function c = barycenter(triangularElement)
            c(1) = mean(triangularElement.nodeArray.getX());
            c(2) = mean(triangularElement.nodeArray.getY());
            c(3) = mean(triangularElement.nodeArray.getZ());
        end
        
        function pl = draw(triangularElement)   
            x = [triangularElement.nodeArray(1).getX, triangularElement.nodeArray(2).getX, ... 
                 triangularElement.nodeArray(3).getX, triangularElement.nodeArray(1).getX];
             
            y = [triangularElement.nodeArray(1).getY, triangularElement.nodeArray(2).getY, ... 
                 triangularElement.nodeArray(3).getY, triangularElement.nodeArray(1).getY];
             
            z = [triangularElement.nodeArray(1).getZ, triangularElement.nodeArray(2).getZ, ... 
                 triangularElement.nodeArray(3).getZ, triangularElement.nodeArray(1).getZ];
             
            pl = line(x,y,z);
        end

        function update(triangularElement)
        end
    end
end

