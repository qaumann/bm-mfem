classdef BiotElement2d4n < QuadrilateralElement
        
    properties (Access = private)

    end



    
    methods
         
     % Constructor
     function biotElement2d4n = BiotElement2d4n(id,nodeArray)
            
        requiredPropertyNames = cellstr(["OMEGA","NUMBER_GAUSS_POINT", "LAMBDA", ...
                "MU","ETA_S","DENSITY_S","DENSITY_F","ETA_F","PRESSURE_0","HEAT_CAPACITY_RATIO",...
                 "PRANDL_NUMBER","POROSITY","TURTUOSITY","STATIC_FLOW_RESISTIVITY",...
                "VISCOUS_CHARACT_LENGTH","THERMAL_CHARACT_LENGTH"]);
            
        % define the arguments for the super class constructor call
        if nargin == 0
            super_args = {};
        elseif nargin == 2
            if ~(length(nodeArray) == 4 && isa(nodeArray,'Node'))
               error('problem with the nodes in element %d', id);
            end
            super_args = {id, nodeArray, requiredPropertyNames};
        end
            
            % call the super class contructor
            biotElement2d4n@QuadrilateralElement(super_args{:});
            biotElement2d4n.dofNames = cellstr(["DISPLACEMENT_X", ...
                "DISPLACEMENT_Y"]);
        end
    
    
     %Initialization
        function initialize(biotElement2d4n)
            biotElement2d4n.lengthX = computeLength(biotElement2d4n.nodeArray(1).getCoords, ...
                biotElement2d4n.nodeArray(2).getCoords);
            
            biotElement2d4n.lengthY = computeLength(biotElement2d4n.nodeArray(1).getCoords, ...
                biotElement2d4n.nodeArray(4).getCoords);
            
            checkConvexity(biotElement2d4n);
        end
        
       
        function responseDoF = getResponseDofArray(element, step)
            
            responseDoF = zeros(12,1);
            for itNodes = 1:1:4
                nodalDof = element.nodeArray(itNodes).getDofArray;
                nodalDof = nodalDof.'
                
                
                for itDof = 3:(-1):1
                    responseDoF(3*itNodes-(itDof-1),1) = nodalDof(4-itDof).getValue(step);
                end
            end
        end
    
        
        
            % Shape Function and Derivatives     
        function [N_mat, N, B_b, B_s, J] = computeShapeFunction(biotElement2d4n,xi,eta)

            N = [(1-xi)*(1-eta)/4    (1+xi)*(1-eta)/4    (1+xi)*(1+eta)/4    (1-xi)*(1+eta)/4];
            
            N_Diff_Par = [-(1-eta)/4    (1-eta)/4   (1+eta)/4   -(1+eta)/4
                -(1-xi)/4     -(1+xi)/4   (1+xi)/4    (1-xi)/4];
            
            N_mat = sparse(2,8);
            N_mat(1,1:2:end) = N(:);
            N_mat(2,2:2:end) = N(:);
            
            % Coordinates of the nodes forming one element
            ele_coords = zeros(4,2);
            for i=1:4
                ele_coords(i,1) = biotElement2d4n.nodeArray(i).getX;
                ele_coords(i,2) = biotElement2d4n.nodeArray(i).getY;
            end
            
             
            % Jacobian
            J = N_Diff_Par * ele_coords;
            
            % Calculation of B-Matrix
            B=J\N_Diff_Par;%/Jdet;
            Bx=B(1,1:4);
            By=B(2,1:4);
            
            % Calculation of B_bending Matrix
            %B_b = sparse(3,8);
            B_b=[Bx(1),0,Bx(2),0,Bx(3),0,Bx(4),0;
                0,By(1),0,By(2),0,By(3),0,By(4);
                By(1),Bx(1),By(2),Bx(2),By(3),Bx(3),By(4),Bx(4)];
            

        end


        function [totalLocalStiffnessMatrix] = computeLocalStiffnessMatrix(biotElement2d4n)
        

            ETA_S = biotElement2d4n.getPropertyValue('ETA_S');
            LAMBDA = biotElement2d4n.getPropertyValue('LAMBDA');
            MU = biotElement2d4n.getPropertyValue('MU');
            OMEGA = biotElement2d4n.getPropertyValue('OMEGA');
            POROSITY = biotElement2d4n.getPropertyValue('POROSITY');
            
        
            HEAT_CAPACITY_RATIO= biotElement2d4n.getPropertyValue('HEAT_CAPACITY_RATIO');    
            PRESSURE_0 = biotElement2d4n.getPropertyValue('PRESSURE_0');
            ETA_F = biotElement2d4n.getPropertyValue('ETA_F');
            PRANDL_NUMBER = biotElement2d4n.getPropertyValue('PRANDL_NUMBER');
            THERMAL_CHARACT_LENGTH = biotElement2d4n.getPropertyValue('THERMAL_CHARACT_LENGTH');
            DENSITY_F = biotElement2d4n.getPropertyValue('DENSITY_F');
            
         
         
            K_f = (HEAT_CAPACITY_RATIO*PRESSURE_0)/(HEAT_CAPACITY_RATIO-(HEAT_CAPACITY_RATIO-1)*...
               (1+(8*ETA_F)/(i*OMEGA*PRANDL_NUMBER*THERMAL_CHARACT_LENGTH^2*DENSITY_F)*...
               (1+(i*OMEGA*PRANDL_NUMBER*THERMAL_CHARACT_LENGTH^2*DENSITY_F)/(16*ETA_F))^(0.5))^(-1));
        
            
            LameCoeff = (1+i*ETA_S)*LAMBDA;
            ShearModulus = (1+i*ETA_S)*MU;
            
            
            
            R = POROSITY*K_f;
            Q = (1-POROSITY)*K_f;
            A = LameCoeff+(1-POROSITY)^2/POROSITY*K_f;
            
            
            D_s = [A+2*MU,A,0;A,A+2*MU,0;0,0,MU];
            D_sf = [Q,Q,0;Q,Q,0;0,0,0];
            D_f = [R,R,0;R,R,0;0,0,0];
                  
            
 
            % Get gauss integration factors:
            [w,g]=returnGaussPoint(p);
           
            
            % Generate empty Stiffnessmatrix:
            
            stiffnessMatrix_s=sparse(8,8);
            stiffnessMatrix_f=sparse(8,8);
            stiffnessMatrix_sf = sparse(8,8);
          
            
            if (biotElement2d4n.getProperties.hasValue('FULL_INTEGRATION')) && (biotElement2d4n.getPropertyValue('FULL_INTEGRATION'))
                for xi = 1 : p
                    for eta = 1 : p
                        [~, ~,B_b, B_s, J] = computeShapeFunction(biotElement2d4n,g(xi),g(eta));

                        stiffnessMatrix_s = stiffnessMatrix_s +             ...
                            B_b' * D_s * B_b * det(J) * w(xi) * w(eta);
           
                        stiffnessMatrix_f = stiffnessMatrix_f +             ...
                            B_b' * D_f * B_b * det(J) * w(xi) * w(eta);
                        
                        stiffnessMatrix_sf = stiffnessMatrix_sf +             ...
                            B_b' * D_sf * B_b * det(J) * w(xi) * w(eta); 
                        
                     end
                 end
            end
            
            % Assemble total Stiffness Matrix:
            
            totalLocalStiffnessMatrix = zeros(16,16);
           
            for i=1:1:8
               for j=1:1:8
               totalLocalStiffnessMatrix(i,j) = stiffnessMatrix_s(i,j); 
               end  
            totalLocalStiffnessMatrix(i,j) = stiffnessMatrix_s(i,j);
            end

            for i=1:1:8
               for j=9:1:16
               totalLocalStiffnessMatrix(i,j) = stiffnessMatrix_sf(i,j); 
               end  
            totalLocalStiffnessMatrix(i,j) = stiffnessMatrix_sf(i,j);
            end

            for i=9:1:16
               for j=1:1:8
               totalLocalStiffnessMatrix(i,j) = stiffnessMatrix_sf(i,j); 
               end  
            totalLocalStiffnessMatrix(i,j) = stiffnessMatrix_sf(i,j);
            end

            for i=9:1:16
               for j=9:1:16
               totalLocalStiffnessMatrix(i,j) = stiffnessMatrix_f(i,j); 
               end  
            totalLocalStiffnessMatrix(i,j) = stiffnessMatrix_f(i,j);
            end
           
        end
                
           
                
        
  
        
        
        function [totalLocalMassMatrix] = computeLocalMassMatrix(quadrilateralElement2d4n)

            STATIC_FLOW_RESISTIVITY = biotElement2d4n.getPropertyValue('STATIC_FLOW_RESISTIVITY');
            POROSITY = biotElement2d4n.getPropertyValue('POROSITY');
            OMEGA = biotElement2d4n.getPropertyValue('OMEGA');
            TORTUOSITY = biotElement2d4n.getPropertyValue('TORTUOSITY');
            ETA_F = biotElement2d4n.getPropertyValue('ETA_F');
            DENSITY_F = biotElement2d4n.getPropertyValue('DENSITY_F');
            DENSITY_S = biotElement2d4n.getPropertyValue('DENSITY_S');
            VISCOUS_CHARACT_LENGTH = biotElement2d4n.getPropertyValue('VISCOUS_CHARACT_LENGTH');
            p = quadrilateralElement2d4n.getPropertyValue('NUMBER_GAUSS_POINT');
            
            % G_J(OMEGA) = flow resistivity of air particles in the pores:
            AirFlowResistivity = (1+(4*i*OMEGA*TORTUOSITY^2*ETA_F*DENSITY_F)/...
                (STATIC_FLOW_RESISTIVITY^2*VISCOUS_CHARACT_LENGTH^2*POROSITY^2))^(0.5);
            
            
            % Viscous Drag accounts for viscous body forces interacting between solid and fluid phases, 
            % proportional to the relative velocity:
            ViscousDrag = STATIC_FLOW_RESISTIVITY*POROSITY^2*AirFlowResistivity;
            

            % Inertial coupling term, related to the tortuosity, increases the fluid density  to model the motion
            % of fluid particles vibrating around the structural frame:
            Rho_a = POROSITY*DENSITY_F*(TORTUOSITY-1);
            
            % Equivalent density-expressions for expressing the elastodynamic coupled equations in condesed form:
            Rho_sf = -Rho_a+i*(ViscousDrag)/(OMEGA);
            Rho_s = (1-POROSITY)*DENSITY_S-Rho_sf;
            Rho_f = POROSITY*DENSITY_F-Rho_sf;
            
            % Generate empty mass matrices:
            M=zeros(8,8);
            totalLocalMassMatrix = zeros(16,16);

            % Calculate geometric-only mass matrix:
            [w,g]=returnGaussPoint(p);
            
            for i=1:p
                xi=g(i);
                for j=1:p
                    eta=g(j);
                    
                    [N_mat, ~, ~, ~, J] = computeShapeFunction(biotElement2d4n,xi,eta);
                    
                    M = M + (w(i)*w(j)*transpose(N_mat)*N_mat*det(J));
                    
                end
             end
            
            
             % Calculate solid, fluid and coupling mass matrices:
             M_s = Rho_s*M;
             M_f = Rho_f*M;
             M_sf = Rho_sf*M;
            
             % Assemble total mass matrix:
             for i=1:1:8
                for j=1:1:8
                totalLocalMassMatrix(i,j) = M_s(i,j); 
                end  
             totalLocalMassMatrix(i,j) = M_s(i,j);
             end

             for i=1:1:8
                for j=9:1:16
                totalLocalMassMatrix(i,j) = M_sf(i,j); 
                end  
             totalLocalMassMatrix(i,j) = M_sf(i,j);
             end

             for i=9:1:16
                for j=1:1:8
                totalLocalMassMatrix(i,j) = M_sf(i,j); 
                end  
             totalLocalMassMatrix(i,j) = M_sf(i,j);
             end

             for i=9:1:16
                for j=9:1:16
                totalLocalMassMatrix(i,j) = M_f(i,j); 
                end  
             totalLocalMassMatrix(i,j) = M_f(i,j);
             end
         end
        

        function dofs = getDofList(element)
            dofs([1 3 5 7])     = element.nodeArray.getDof('DISPLACEMENT_SOLID_X');
            dofs([2 4 6 8])     = element.nodeArray.getDof('DISPLACEMENT_SOLID_Y');
            dofs([9 11 13 15])  = element.nodeArray.getDof('DISPLACEMENT_FLUID_X');
            dofs([10 12 14 16]) = element.nodeArray.getDof('DISPLACEMENT_FLUID_Y');
        end
        
        
        function vals = getValuesVector(element, step)
            vals = zeros(1,16);
            
            vals([1 3 5 7])     = element.nodeArray.getDofValue('DISPLACEMENT_SOLID_X',step);
            vals([2 4 6 8])     = element.nodeArray.getDofValue('DISPLACEMENT_SOLID_Y',step);
            vals([9 11 13 15])  = element.nodeArray.getDofValue('DISPLACEMENT_FLUID_X',step);
            vals([10 12 14 16]) = element.nodeArray.getDofValue('DISPLACEMENT_FLUID_Y',step);
        end
             
             
        function vals = getFirstDerivativesVector(element, step)
            vals = zeros(1,16);
            
            [~, vals([1 3 5 7]), ~]     = element.nodeArray.getDof('DISPLACEMENT_SOLID_X').getAllValues(step);
            [~, vals([2 4 6 8]), ~]     = element.nodeArray.getDof('DISPLACEMENT_SOLID_Y').getAllValues(step);
            [~, vals([9 11 13 15]), ~]  = element.nodeArray.getDof('DISPLACEMENT_FLUID_X').getAllValues(step);
            [~, vals([10 12 14 16]), ~] = element.nodeArray.getDof('DISPLACEMENT_FLUID_Y').getAllValues(step);
            
        end
        
        function vals = getSecondDerivativesVector(element, step)
            vals = zeros(1,16);
            
            [~, ~, vals([1 3 5 7])]     = element.nodeArray.getDof('DISPLACEMENT_SOLID_X').getAllValues(step);
            [~, ~, vals([2 4 6 8])]     = element.nodeArray.getDof('DISPLACEMENT_SOLID_Y').getAllValues(step);
            [~, ~, vals([9 11 13 15])]  = element.nodeArray.getDof('DISPLACEMENT_FLUID_X').getAllValues(step);
            [~, ~, vals([10 12 14 16])] = element.nodeArray.getDof('DISPLACEMENT_FLUID_Y').getAllValues(step);
          
        end
        
        
 
        function update(biotElement2d4n)
        end
        
        function F = computeLocalForceVector(biotElement2d4n)
            F = zeros(1,16);
        end
        
    end
end