classdef FetiPreparer < SimpleSolvingStrategy
    %class that prepares problem for the PCPG Algorithm of Feti Level 1 and
    %2 Methods. E.g. find pseudo Inverse, Body Modes,... 
    
    properties
    end
    
    methods (Static)
        function [u] = solveFeti(K,f,substructures)
            
            %see whether the subdomains are singular or not
            singulars = [];
            for ii = 1:length(K)
                if length(K{1,ii}) ~= rank(K{1,ii})
                    method = 'singular';
                    singulars = [singulars ii];
                end
            end
            
            %find dimensions of the problem
            dim = Substructure.findDim(substructures(1,1));

            %intfNodes = Cell array showing the interface configurations 
            %between the substructures. Each row corresponds to a
            %substructur, each column to another substructure, the entries
            %show the interface nodes between those two substructures
            %allIntfNodes = Array containing all the interface nodes found
            %in the system. here some nodes are doubled because they are
            %taken from both sides of the interface
            [intfNodes, allIntfNodes] = FetiPreparer.findInterfaceNode(substructures);
            %allNodesIntf = All interface nodes found for the whole system.
            %this time duplicates are removed
            allNodesIntf = FetiPreparer.findSystemInterfaceNodes(allIntfNodes);
            
            if strcmp(method, 'singular')    
                %Rigid Body Modes
                R = cell(1,length(K));
                %pseudo inverse
                Kinv = cell(1,length(K));
                %Boolean Matrix
                B = cell(1,length(K));
                %test variable for correct pseudo Inverse/Body Modes
                test = 0;
                for it = 1:length(K)
                    if ismember(it, singulars)
                        %find pseudo Inverse/body modes for singulars
                        [r, kinv, test] = FetiPreparer.psInvRBM(K{1,it},test);
                        R{1,it} = r;
                        Kinv{1,it} = kinv;
                    else
                        %pseudo Inverse/body modes set to zero for
                        %non-singular subdomain
                        R{1,it} = 0;
                        Kinv{1,it} = 0;
                    end           
                    %create Boolean Matrix
                    B{1,it} = FetiPreparer.createBooleanMatrix...
                    (substructures, intfNodes, it, allIntfNodes, allNodesIntf, dim);
                end

                %ATTENTION: Still a manual change needed for the Boolean
                %Matrices, so assign the correct sign:
                B{1,2} = -B{1,2};
                B{1,3} = -B{1,3};
                B{1,6} = -B{1,6};
%                 B{1,8} = -B{1,8};
                
                %find matrix C
                C = FetiPreparer.findC(substructures,intfNodes,allNodesIntf,dim);
                
                %find matrix W, which scales the preconditioners.
                W = FetiPreparer.findW(substructures,intfNodes,allNodesIntf,dim);
                
                %test for correct Pseudo Invers and Rigid Body Modes
                if test ~= 2*length(singulars)
                    disp('ERROR: Pseudo Invers and/or Rigid Body Modes are not correct!');
                end
                
                %all information given to the pCG is in cell array format
                %with one row and number of columns corresponding to the
                %number of subdomains

                %FETI 2 Level
                [lambda, alpha] = Feti2Solver.pCG(K,f,B,R,Kinv,C,W);
                %FETI 1 Level
                %[lambda, alpha] = Feti1Solver.pCG(K,f,B,R,Kinv);
                
                %calculate displacements from lambda and alpha
                for numSubs = 1:length(substructures)
                    if Kinv{1,numSubs} == 0
                        u{1,numSubs} = inv(K{1,numSubs})*(f{1,numSubs}'-B{1,numSubs}'*lambda);
                    else
                        u{1,numSubs} = Kinv{1,numSubs}*(f{1,numSubs}'-B{1,numSubs}'*lambda)+R{1,numSubs}*alpha{1,numSubs};
                    end
                end

                %check Interface condition
                %B{1,1}*u{1,1}+B{1,2}*u{1,2}+B{1,3}*u{1,3}+B{1,4}*u{1,4};
                
                %B{1,1}*u{1,1}+B{1,2}*u{1,2};

             else
                lenU = 0;
                %define size for u
                for jj = 1:length(f)
                    lenU = lenU+length(f{jj});
                end
                
                u = zeros(lenU, 1);
                ll = 1;
                %assign displacements to u by doing matrix left division
                for kk = 1:length(K)
                    u(ll:ll+length(f{kk})-1,1) = K{kk}\f{kk}';
                    ll = ll+length(f{kk});
                end
            end
        end
        
        function C = findC(substructures,intfNodes,allNodesIntf,dim)
            nodes = cell(1,length(substructures));
            multiNodes = [];
            %find all interface nodes of all substructures and of these 
            %nodes find the ones which occur more than twice, cross-points
            for numSubs = 1:length(substructures)
                for numSub = 1:length(substructures)
                    nodes{1,numSubs} = [nodes{1,numSubs} intfNodes{numSubs,numSub}];
                    nodesU{1,numSubs} = unique([nodes{1,numSubs}]);
                end
                %see how many times a certain node occurs
                for numNodes = 1:length(nodesU{1,numSubs})
                    %more than twice?
                    if sum(ismember(nodes{1,numSubs},nodesU{1,numSubs}(numNodes))) > 2
                        multiNodes = [multiNodes nodesU{1,numSubs}(numNodes)];
                    end
                end
            end
            
            %eliminate the nodes which occur multiple times, but are just a
            %copy of another node at an interface boundary.
            numNodes = 1;
            while numNodes <= length(multiNodes)
                coord = multiNodes(numNodes).getCoords;
                numNode = 1;
                while numNode <= length(multiNodes)
                    if numNode ~= numNodes
                        coord2 = multiNodes(numNode).getCoords;
                        if coord == coord2
                            multiNodes(numNode) = [];
                            multiNodes.getId;
                            numNode;
                        else
                            numNode = numNode+1;
                        end
                    else
                        numNode = numNode+1;
                    end
                end
                numNodes = numNodes+1;
            end
            
            %for FETI 1 Method, ignore C
            if isempty(multiNodes) 
                C = 0;
            end
            
            %go through all nodes at the interfaces and set the entry of
            %matrix C to 1 if the interface node is a node which occurs
            %multiple times.
            for numNodes = 1:length(multiNodes)
                coord = multiNodes(numNodes).getCoords;
                ii = 0;
                for numNode = 1:length(allNodesIntf)
                    dofs = allNodesIntf(numNode).getDofArray;
                    for dof = 1:dim
                        if ~dofs(dof).isFixed
                            ii = ii+1;
                            coord2 = allNodesIntf(numNode).getCoords;
                            if coord == coord2
                                C(ii,numNodes) = 1;
                            else
                                C(ii,numNodes) = 0;
                            end
                        end
                    end
                end
            end
        end
        
        %find all nodes at the systems interfaces but only one of the two
        %or more nodes per interface connection
        function allIntfNodes = findSystemInterfaceNodes(totIntfArray)
            
            %all interface nodes in the system
            totIntfArray = unique(totIntfArray);
            [~,idx] = sort([totIntfArray.getId]);
            allIntfNodes = totIntfArray(idx);
            %allIntfNodes.getId
            numNodes = 1;
            while numNodes <= length(allIntfNodes)
                coords = allIntfNodes(numNodes).getCoords;
                itNodes = 1;
                while itNodes <= length(allIntfNodes)
                    if allIntfNodes(numNodes).getId ~= allIntfNodes(itNodes).getId
                        allIntfNodes(itNodes).getId;
                        coords2 = allIntfNodes(itNodes).getCoords;
                        if coords == coords2
                            allIntfNodes(itNodes) = [];
                        else
                            itNodes = itNodes+1;
                        end
                    else
                        itNodes = itNodes+1;
                    end
                end
                numNodes = numNodes+1;
            end
        end
        
        %find W matrix, which is diagonal and has as diagonal elements the
        %inverse of the multiplicity of substructures an interface dof 
        %belongs to
        function W = findW(substructures,intfNodes,allNodesIntf,dim)
            numDof = 0;
            for numNodes = 1:length(allNodesIntf)
                dofs = allNodesIntf(numNodes).getDofArray;
                for dof = 1:dim
                    if ~dofs(dof).isFixed
                        numDof = numDof+1;
                    end
                end
            end
            
            W = zeros(numDof,numDof);
            ii = 0;
            for numNodes = 1:length(allNodesIntf)
                dofs = allNodesIntf(numNodes).getDofArray;
                for dof = 1:2
                    if  ~dofs(dof).isFixed
                        ii = ii+1;
                        coords = allNodesIntf(numNodes).getCoords;
                        count = 0;
                        for numSubs = 1:length(substructures)
                            allNodes = substructures(numSubs).getAllNodes;
                            for numNode = 1:length(allNodes)
                                coords2 = allNodes(numNode).getCoords;
                                if coords == coords2
                                    count = count+1;
                                end
                            end
                        end
                    else
                        continue;
                    end
                    W(ii,ii) = 1/count;
                end
            end
        end
        
        function [intfNodes, allIntfNodes] = findInterfaceNode(substructures)
            
            %find interface nodes of the substructures: intfNodes is a cell
            %array which contains all interface nodes of a substructure in
            %a row. The columns indicate with which other substructure the
            %interface exists.
            intfNodes = {};
            %allIntfNodes just collects all nodes at the interface that
            %between a substructure and all other substructures in the
            %system
            allIntfNodes = [];
            %iterate over all substructures
            for itS = 1:length(substructures)
                nodes = substructures(itS).getAllNodes;
                %iterate over all substructures not chosen now 
                for itOn = 1:length(substructures)
                    copies = [];
                    if itOn ~= itS
                        subsNodes = substructures(itOn).getAllNodes;
                    else
                        continue;
                    end
                    %iterate over all nodes of substructure of interest
                    for itN = 1:length(nodes)
                        %find interface nodes
                        nodeIntf = findIntfNode(nodes(itN),subsNodes);
                        if nodeIntf.getId ~= 0
                            copies = [copies nodeIntf];
                        end
                    end
                    intfNodes{itS, itOn} = [copies];
                    allIntfNodes = [allIntfNodes copies];
                end
            end
        end
        
        function [R, pseudoInv, test] = psInvRBM(K, test)
            %function coordinating the cholesky decomposition, pseudo inverse
            %generation and also the generation of the rigid body modes
            
            %do cholesky decomposition to get cholesky factors and Kpr
            %needed to compute body modes
            
            [KppFactors, Kpr, clm] = FetiPreparer.choleskyDecomp(K);

            %matrix of rigid body modes is created
            R = FetiPreparer.createBodyModesMatrix(KppFactors, Kpr, clm);
            
            %create pseudo inverse
            pseudoInv = FetiPreparer.createPseudoInv(KppFactors, clm);
            
            

            %test for rigid body modes. 10 decimal places
            nullspace = round(K*R, 9);
            if nullspace == 0
                test = test+1;
            end

            %test for pseudo inverse. 5 decimal places
            a = round(K,5);
            b = round(K*pseudoInv*K,5);
            if ismember(b,a) == 1
                test = test+1;
            end         
        end
        
        function [KppFac, Kpr, rowDeleted] = choleskyDecomp(K)
            %   Function performing the cholesky decomposition. The matrix
            %   Kpr needed to compute the rigid body modes is calculated as
            %   well.
            
            %length of K
            n = length(K);
            KppFac = zeros(n,n);
            %indice for KppFactors
            indKpp = 1;
            %indice for stiffness matrix
            indK = 1;
            %counts the times a row and column is deleted
            cntRow = 0;
            Kpr = [];
            %safes the indices of rows and columns that are deleted
            rowDeleted = [1];
            
            while indKpp <= n
               %diagonal elements of cholesky factorization 
               KppFac(indKpp,indKpp) = sqrt(K(indK,indK) - ...
                                     KppFac(1:(indKpp-1),indKpp)'* ... 
                                     KppFac(1:(indKpp-1),indKpp));
               
               %for zero pivot delete row, column and safe their indice
                if KppFac(indKpp,indKpp) < 2*10^-5
                    cntRow = cntRow+1;
                    %Matrix to compute rigid body modes
                    Kpr(1:(indKpp-1),cntRow)= -KppFac(1:(indKpp-1),indKpp);
                    %delete rows and columns
                    KppFac = removerows(KppFac, 'ind', indKpp);
                    KppFac = (removerows(KppFac', 'ind', indKpp))';               
                    %remember which rows, columns are deleted
                    rowDeleted = [rowDeleted, indK];
                    %decrease ii and n after deleting a row
                    n = n-1;
                    indKpp = indKpp-1;
                else             
                    %if no zero-Pivot, contiue as usual
                    jj = indKpp+1;
                    nn = indK+1;
                    while jj <= n
                        KppFac(indKpp,jj) = (K(indK,nn) - ...
                            KppFac(1:(indKpp-1),indKpp)'* ...
                            KppFac(1:(indKpp-1),jj))/KppFac(indKpp,indKpp);
                        jj = jj+1;
                        nn = nn+1;
                    end
                end
                indKpp = indKpp+1;
                indK = indK+1;
            end
        end
        
        function R = createBodyModesMatrix(KppFactors, Kpr, clm)
            %function creating the matrix of rigid body modes
            
            %PROBLEM: maybe the assembly of the R matrix is not completly
            %right. needs to be further tested

            %backward substitution on R
            len = length(clm)-1;
            R = KppFactors\Kpr;
            R = [R; zeros(len,len)];
            
            %insert identity matrix under/into body modes. They need to be
            %at the position of the deleted zero-pivot
            for ii = 2:length(clm)
                if clm(ii) < size(R,1)
                    %safe row in which one for zero-pivot is inserted
                    temp1 = R(clm(ii),:);
                    for numRows = clm(ii):size(R,1)-1
                        %set row of zero-pivot to zero and move entries one row
                        %down. this implies only identity one is in that row.
                        %R(numRows,:) = zeros(1, size(R,2));
                        temp = R(numRows+1,:);
                        R(numRows+1,:) = temp1;
                        temp1 = temp;
                    end
                    %set zero-pivot location to 1
                    R(clm(ii),:) = zeros(1, size(R,2));
                    R(clm(ii),ii-1) = 1;
                    
                %in last row just add the one instead of zero-pivot
                else
                     R(clm(ii),ii-1) = 1;
                end
            end
        end
        
        function pseudoInv = createPseudoInv(KppFactors, clm)
            %function that creates the pseudo inverse
            
            %get full rank submatrix of stiffness matrix
            Kpp = KppFactors'*KppFactors;
            KppInv = inv(Kpp);
            pseudoInv = [];
            
           
            
            for ii = 2:length(clm)      
                %if deleted rows/columns have non redundant
                %rows/columns in between
                if clm(ii)-clm(ii-1) > 1            
                    diff = clm(ii)-clm(ii-1);
                    %first iteration create basic pseudoInv
                    if ii == 2
                        basePart = [KppInv(1:(clm(ii)-1), clm(ii-1):(clm(ii)-1))];
                        %can be deleted I think  
                        %pseudoInv = [pseudoInv, basePart];
                        pseudoInv = [basePart];
                    %all further iterations
                    else
                        %wenn Zeilen verschoben werden
                        if clm(ii) <= size(KppInv,2)
                            cols = clm(ii);
                        else
                            cols = size(KppInv,2);
                        end
                        %basePart is column of a non redundant column
                        %between redundant ones. basePart2 same for rows
                        
                        %%%CHANGE zeros(diff-1,diff) to zeros(1,diff-1)
                        basePart = [KppInv(1:(clm(ii-1)-1), clm(ii-1):cols); zeros(1, diff-1)];           
                        basePart2 = [KppInv(clm(ii-1):cols, 1:clm(ii-1)-1), zeros(diff-1, 1), KppInv(clm(ii-1):cols,clm(ii-1):cols)];
                        
                        pseudoInv = [pseudoInv, basePart; basePart2];
                    end
                    
                    %dimensions of pseudoInv 
                    high = size(pseudoInv,1);
                    len = size(pseudoInv,2); 
                    %insert zeros after a block of non-redundant rows,
                    %columns to display next redundant equation.
                    pseudoInv = [pseudoInv, zeros(high,1); zeros(1,len+1)];

                %another zero line/column inserted if a deleted row/column
                %directly follows another
                else
                    high = size(pseudoInv,1);
                    len = size(pseudoInv,2);
                    pseudoInv = [pseudoInv, zeros(high,1); zeros(1,len+1)]; 
                end

            end             
        end
        
        %Function creating the Boolean Matrix, named 'B' here, for each 
        %substructure. 
        function B = createBooleanMatrix(substructures,... 
            intfNodes, it, totIntfArray, allNodesIntf, dim)
            
            allNodes = substructures(it).getAllNodes;
            %find number of free dofs in substructure
            numDofs = 0;
            for numNodes = 1:length(allNodes)
                dofs = allNodes(numNodes).getDofArray;
                for dof = 1:dim
                    if ~dofs(dof).isFixed
                        numDofs = numDofs+1;
                    end
                end
            end
            
            %find number of free dofs at System Interfaces
            numIntfDofs = 0;
            for numNodes = 1:length(allNodesIntf)
                dofs = allNodesIntf(numNodes).getDofArray;
                for dof = 1:dim
                    if ~dofs(dof).isFixed
                        numIntfDofs = numIntfDofs+1;
                    end
                end
            end

            %Find nodes at the interface of the substructure. Exclude case
            %of interfaces sharing just one node, which happens for 
            %substructures which are across from each other and only share 
            %one node.
            nodesIntf = [];
            for numSubs = 1:length(substructures)
                if numel(intfNodes{it,numSubs}) > 1
                    nodesIntf = [nodesIntf intfNodes{it,numSubs}];
                end
            end

            %order nodes at the interface by Id
            [~,idx] = sort([nodesIntf.getId]);
            nodesIntf = nodesIntf(idx);
            
            %find row indices of the Boolean matrix that need to be set to
            %one for each interface dof
            count = 0;
            indices = [];
            for itNodes = 1:length(allNodesIntf)
                dofs = allNodesIntf(itNodes).getDofArray;
                for dof = 1:dim
                    if ~dofs(dof).isFixed
                        count = count+1;
                        for numNodes = 1:length(nodesIntf)
                            if nodesIntf(numNodes).getCoords == ...
                                allNodesIntf(itNodes).getCoords
                                indices = [indices count];
                            end
                        end
                    end
                end
            end 
            
            %find column indices of the Boolean matrix that need to be set
            %to one for each interface dof
            indices2 = [];
            for itNodes = 1:length(allNodesIntf)
                count = 0;
                for numNodes = 1:length(allNodes)
                    dofs = allNodes(numNodes).getDofArray;
                    for dof = 1:dim
                        if ~dofs(dof).isFixed
                            count = count+1;
                            if allNodesIntf(itNodes).getCoords == ...
                               allNodes(numNodes).getCoords
                                indices2 = [indices2 count];
                            end
                        end

                    end
                end
            end
            
            %See how often one specific column indice (indices2) appears.
            %then add those indices up. this is the same as adding the
            %contributions from different interface configurations together
            num = 1;
            jj = 0;
            for numIndi = 2:length(indices)
                num = num+1;
                if indices(numIndi) == indices(numIndi-1)
                    jj = 0;
                    for ii = num:length(indices2)+1
                        indices2(length(indices2)+1-jj) = indices2(length(indices2)-jj);
                        jj = jj+1;
                    end
                    indices2(num) = indices2(num-1);
                end
            end
            
            %create Boolean matrix
            B = zeros(numIntfDofs, numDofs);
            for numIndi = 1:length(indices)
                B(indices(numIndi), indices2(numIndi)) = B(indices(numIndi), indices2(numIndi))+1;
            end
        end 
    end 
end