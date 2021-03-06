classdef AnsysInput < ModelIO
    %AnsysInput Read model input from ANSYS
    %   Detailed explanation goes here
    
    properties (Access = private)
        ansysExecutable
        printOutput = false
    end
    
    methods
        
        function obj = AnsysInput(file, ansysExecutable)
            % file - full file path with filetype as extensions
            % exaample: file='F:\ALMA_simulations\AnsysModels\plate.inp';
            % ansysExecutable - full file path of Ansys executable
            %
            if nargin == 0
                super_args = {};
            elseif nargin == 2
                if ~ exist(file, 'file')
                    msg = ['AnsysInput: File ', file, ' not found.'];
                    e = MException('MATLAB:bm_mfem:fileNotFound',msg);
                    throw(e);
                end
                super_args = {file};
            else
                msg = 'AnsysInput: Wrong number of input arguments';
                err = MException('MATLAB:bm_mfem:invalidArguments',msg);
                throw(err);
            end
            
            obj@ModelIO(super_args{:});
            
            if exist(ansysExecutable, 'file') == 2
                obj.ansysExecutable = ansysExecutable;
            else
                msg = ['AnsysInput: Ansys executable could not be found at' ...
                    ' specified location ', ansysExecutable];
                err = MException('MATLAB:bm_mfem:ansysNotFound',msg);
                throw(err);
            end
        end
        
        function model = readModel(obj)
            
            A=strsplit(obj.file,'\');
            B=strsplit(A{end},'.');
            C=strsplit(obj.file,B{1});
            
            if strcmp(A{1},obj.file)
                folder = [pwd '\'];
            else
                folder=C{1};
            end
            
            if strcmp(B{1},A{end})
                msg = 'AnsysInput: file type not found.';
                e = MException('MATLAB:bm_mfem:filetypeNotFound',msg);
                throw(e);
            else
                fileName=B{1};
                extension=B{end};
            end
            
            if obj.printOutput
                disp('Ansys input file selected')
                disp(['folder: ' folder])
                disp(['filename: ' fileName])
                disp(['filetype: ' extension])
                disp('Running ANSYS ...')
            end
            
            model = FemModel;
            obj.runAnsys(obj.ansysExecutable,folder,fileName,extension);
            obj.readErrorLog(obj.printOutput);
            
            if obj.printOutput
                disp('... done')
                disp('Reading ANSYS model ...')
                tic
            end
            
            % Read restriction on the nodes
            data.nodeRest = obj.readRestrictions();
            % Read loads on the nodes
            data.nodeLoads = obj.readLoads();
            % Read record 5 of ANSYS to get the position of the entries
            % of each node with the matrices
            nodeEquiv = obj.readRecord_5();
            % Read the coordinates of each node
            data.nodeList = obj.readCoord();
            % Order the coordinates acoording to the record 5
            [~, order] = ismember(nodeEquiv.', data.nodeList(:,1));
            nodesC = data.nodeList(order,:);
            data.nodesOrderByDofs=nodesC(:,1)';
            % Read available element data
            [data.elementsOfModel,data.nodeElementList,data.nodeConnectivity] = AnsysInput.readElements();
            % Read surface loads
            data.nodeSurfaceLoads = obj.readSurfaceLoads(data.nodeList);
            
            % Create objects "Node" and assign them to a model
            nodeArray = Node.empty;
            for ii=1:size(nodesC,1)
                nodeArray(ii) = Node(nodesC(ii,1),nodesC(ii,2),nodesC(ii,3),nodesC(ii,4));
            end
            model.addNodes(nodeArray);
            data.numNodes = length(model.getAllNodes());
            
            % Assign dofs to node
            for i = 1 :size(data.elementsOfModel,1)
                nodeData=cell2mat(data.nodeElementList(i));
                [dofs, ~] = AnsysInput.getAnsysElementInfo(data.elementsOfModel{i,1}, data.elementsOfModel{i,2});
                nodeData(isnan(nodeData)) = [];
                for j = 1:length(nodeData)
                    n = model.getNode(nodeData(j));
                    n.addDof(dofs);
                end
            end
            % Order dofs by nodes (bm-mfem style; the dummy element takes
            % care of reordering the matrices)
            dofArray = arrayfun(@(node) node.getDofArray, model.getAllNodes(), 'UniformOutput', false);
            dofArray = [dofArray{:}];
            for ii = 1:length(dofArray)
                dofArray(ii).setId(ii);
            end
            
            % Create the dummy element
            e = model.addNewElement('DummyElement',1,model.getAllNodes);
            
            % Read matrices
            data.Mansys = HBread('DataAnsys/HBMmass.txt');
            data.Kansys = HBread('DataAnsys/HBMstiff.txt');
            data.Cansys = HBread('DataAnsys/HBMdamp.txt');
            
            % Set the matrices
            systemSize = size(data.Mansys,1);
            Mdiag = spdiags(data.Mansys,0);
            M = data.Mansys + data.Mansys.' - spdiags(Mdiag(:),0,systemSize,systemSize);
            Cdiag = spdiags(data.Cansys,0);
            C = data.Cansys + data.Cansys.' - spdiags(Cdiag(:),0,systemSize,systemSize);
            Kdiag = spdiags(data.Kansys,0);
            K = data.Kansys + data.Kansys.' - spdiags(Kdiag(:),0,systemSize,systemSize);
            e.setMatrices(M, C, K);
            
            % Set the dof order
            e.setDofOrder(data.nodesOrderByDofs);
            
            % Set restrictions
            e.setDofRestrictions(data.nodeRest);
            
            % Set loads
            for ii=1:length(data.nodeLoads{1})
                n = model.getNode(data.nodeLoads{1}(ii));
                n.setDofLoad(data.nodeLoads{2}{ii}, data.nodeLoads{3}(ii));
            end
            
            % Set surface loads. Works only for 3d models!
            for ii=1:size(data.nodeSurfaceLoads,1)
                sfl = data.nodeSurfaceLoads(ii,:);
                n = model.getNode(data.nodeSurfaceLoads(ii,1));
                n.setDofLoad('DISPLACEMENT_X',sfl(4)*(sfl(2)+1i*sfl(3)));
                n.setDofLoad('DISPLACEMENT_Y',sfl(5)*(sfl(2)+1i*sfl(3)));
                n.setDofLoad('DISPLACEMENT_Z',sfl(6)*(sfl(2)+1i*sfl(3)));
            end
            
            % Set node connectivity
            e.setNodeConnectivity(data.nodeConnectivity);
            
            % Add everything to a model part
            model.addNewModelPart('ANSYS_model', ...
                model.getAllNodes(), model.getAllElements());
            
            try
                rmdir('DataAnsys', 's')
            catch
            end
            
            if obj.printOutput
                runtime = toc;
                disp(['... done in ', num2str(runtime)])
            end
        end
        
        function setPrintOutput(obj, print)
            if isa(print, 'logical')
                obj.printOutput = print;
            else
                msg = 'AnsysInput: Input argument must be a logical';
                err = MException('MATLAB:bm_mfem:invalidArguments',msg);
                throw(err);
            end
        end
        
    end
    
    methods (Static)
        
        function runAnsys(ansysExecutable,folder,file,extension)
            % make directory for files
            if ~exist('DataAnsys','dir'); mkdir('DataAnsys'); end
            
            % Header
            fidl=fopen('DataAnsys/modelFile.txt','w');
            % Read input file
            fprintf(fidl,'/INPUT,%s,%s,%s,,0 \r\n',file...
                ,extension...
                ,folder);
            % Enters the preprocessor
            fprintf(fidl,'/PREP7 \r\n');
            % Set EMAWRITE to "yes" to obtain binary files
            fprintf(fidl,'EMATWRITE,YES \r\n');
            % Create external file with the nodal information
            fprintf(fidl,'/output,DataAnsys/nodeCoor,txt \r\n');
            fprintf(fidl,'NLIST,ALL,,,XYZ,NODE,NODE,NODE \r\n');
            fprintf(fidl,'/output \r\n');
            % Create external file with the restricted DoF
            fprintf(fidl,'/output,DataAnsys/nodeRest,txt \r\n');
            fprintf(fidl,'DLIST,ALL,\r\n');
            fprintf(fidl,'/output \r\n');
            % Create external file with loads
            fprintf(fidl,'/output,DataAnsys/nodeLoads,txt \r\n');
            fprintf(fidl,'FLIST,ALL,\r\n');
            fprintf(fidl,'/output \r\n');
            % Create external file with surface loads
            fprintf(fidl,'/output,DataAnsys/nodeSurfaceLoads,txt \r\n');
            fprintf(fidl,'SFLIST,ALL,\r\n');
            fprintf(fidl,'/output \r\n');
            % Create external file with body forces
            fprintf(fidl,'/output,DataAnsys/nodeBodyLoads,txt \r\n');
            fprintf(fidl,'BFLIST,ALL,\r\n');
            fprintf(fidl,'/output \r\n');
            % Create external file with the element type
            fprintf(fidl,'/output,DataAnsys/elemTyp,txt \r\n');
            fprintf(fidl,'ETLIST,ALL,\r\n');
            fprintf(fidl,'/output \r\n');
            % Create external file with the element nodes
            fprintf(fidl,'/output,DataAnsys/elemNodes,txt \r\n');
            fprintf(fidl,'ELIST,ALL,\r\n');
            fprintf(fidl,'/output \r\n');
            % Create external file with the material information
            fprintf(fidl,'/output,DataAnsys/materialPro,txt \r\n');
            fprintf(fidl,'MPLIST,ALL,,,EVLT\r\n');
            fprintf(fidl,'/output \r\n');
            % Set solver
            fprintf(fidl,'/SOLU\r\n');
            fprintf(fidl,'ANTYPE,MODAL\r\n');
            fprintf(fidl,'MODOPT,DAMP,1\r\n');
            fprintf(fidl,'MXPAND,1,,,YES\r\n');
            fprintf(fidl,'WRFULL,1\r\n');
            fprintf(fidl,'SOLVE\r\n');
            fprintf(fidl,'FINISH\r\n');
            % Extract the mass, damping and stifness matrix
            fprintf(fidl,'/AUX2\r\n');
            fprintf(fidl,'file,,full\r\n');
            
            fprintf(fidl,...
                'HBMAT,DataAnsys/HBMstiff,txt,,ascii,stiff,yes,yes\r\n');
            
            fprintf(fidl,...
                'HBMAT,DataAnsys/HBMmass,txt,,ascii,mass,yes,yes\r\n');
            
            fprintf(fidl,...
                'HBMAT,DataAnsys/HBMdamp,txt,,ascii,damp,yes,yes\r\n');
            
            fprintf(fidl,'FINISH\r\n');
            % Get the modified nodal information
            fprintf(fidl,'/AUX2\r\n');
            fprintf(fidl,'/output,DataAnsys/record_5,txt \r\n');
            fprintf(fidl,'form,long\r\n');
            fprintf(fidl,'fileaux2,,emat,%s\r\n',folder);
            fprintf(fidl,'dump,5,5\r\n');
            fprintf(fidl,'/output \r\n');
            fprintf(fidl,'FINISH\r\n');
            fclose(fidl);
            
            % Run ANSYS
            eval(['!"' ansysExecutable '" -b  -i DataAnsys/modelFile.txt -o DataAnsys/result.out'])
            
            % Delete files
            try
                delete('*.emat');
                delete('*.esav');
                delete('*.full');
                delete('*.mlv');
                delete('*.db');
                delete('*.log');
                delete('*.BCS');
                delete('*.ce');
                delete('*.mode');
                delete('*.stat');
                delete('*.xml');
            catch
            end
        end
        
        function [dofs, nnodes] = getAnsysElementInfo(elementName, keyopts)
        %GETANSYSELEMENTINFO return information about ANSYS elements
        %   [dofs, nnodes] = GETANSYSELEMENTINFO(elementName, keyopts)
        %   returns the dofs and number of nodes of the ANSYS element
        %   specified in elementName based on the chosen keyopts. If no
        %   keyopts are specified, they are assumed to be all set to 0.
            if nargin == 1
                keyopts = zeros(1,18);
            end
            
            ux = "DISPLACEMENT_X";
            uy = "DISPLACEMENT_Y";
            uz = "DISPLACEMENT_Z";
            rx = "ROTATION_X";
            ry = "ROTATION_Y";
            rz = "ROTATION_Z";
            
            switch 1
                case strcmp(elementName,'BEAM3')
                    dofs = [ux uy rz];
                    nnodes = 2;
                    
                case strcmp(elementName,'COMBIN14')
                    if keyopts(2) == 0
                        if keyopts(3) == 0
                            dofs = [ux uy uz];
                        elseif keyopts(3) == 1
                            dofs = [rx ry rz];
                        elseif keyopts(3) == 2
                            dofs = [ux uy];
                        elseif keyopts(3) == 4
                            dofs = [ux uy];
                        else
                            msg = ['AnsysInput: Invalid keyopts for element type ', ...
                                elementName];
                            e = MException('MATLAB:bm_mfem:invalidKeyopts',msg);
                            throw(e);
                        end
                    elseif keyopts(2) == 1
                        dofs = ux;
                    elseif keyopts(2) == 2
                        dofs = uy;
                    elseif keyopts(2) == 3
                        dofs = uz;
                    elseif keyopts(2) == 4
                        dofs = rx;
                    elseif keyopts(2) == 5
                        dofs = ry;
                    elseif keyopts(2) == 6
                        dofs = rz;
                    else
                        msg = ['AnsysInput: Invalid keyopts for element type ', ...
                            elementName];
                        e = MException('MATLAB:bm_mfem:invalidKeyopts',msg);
                        throw(e);
                    end
                    nnodes = 2;
                    
                case strcmp(elementName,'MASS21')
                    if keyopts(3) == 0
                        dofs = [ux uy uz rx ry rz];
                    elseif keyopts(3) == 2
                        dofs = [ux uy uz];
                    elseif keyopts(3) == 3
                        dofs = [ux uy rz];
                    elseif keyopts(3) == 4
                        dofs = [ux uy];
                    else
                        msg = ['AnsysInput: Invalid keyopts for element type ', ...
                            elementName];
                        e = MException('MATLAB:bm_mfem:invalidKeyopts',msg);
                        throw(e);
                    end
                    nnodes = 1;
                    
                case strcmp(elementName,'SHELL63')
                    dofs = [ux uy uz rx ry rz];
                    nnodes = 4;
                    
                case strcmp(elementName,'SURF154')
                    dofs = [ux uy uz];
                    if keyopts(4) == 0
                        nnodes = 8;
                    elseif keyopts(4) == 1
                        nnodes = 4;
                    else
                        msg = ['AnsysInput: Invalid keyopts for element type ', ...
                            elementName];
                        e = MException('MATLAB:bm_mfem:invalidKeyopts',msg);
                        throw(e);
                    end
                    
%                 case strcmp(elementName,'TARGE170')
%                     dofs = [ux uy uz];
%                     
%                 case strcmp(elementName,'CONTA174')
%                     if keyopts(1) == 0
%                         dofs = [ux uy uz];
%                     else
%                         msg = ['AnsysInput: Invalid keyopts for element type ', ...
%                             elementName];
%                         e = MException('MATLAB:bm_mfem:invalidKeyopts',msg);
%                         throw(e);
%                     end
                    
                case strcmp(elementName,'SHELL181')
                    if keyopts(1) == 0
                        dofs = [ux uy uz rx ry rz];
                    elseif keyopts(1) == 1
                        dofs = [ux uy uz];
                    else
                        msg = ['AnsysInput: Invalid keyopts for element type ', ...
                            elementName];
                        e = MException('MATLAB:bm_mfem:invalidKeyopts',msg);
                        throw(e);
                    end
                    nnodes = 4;
                    
                case strcmp(elementName,'PLANE182')
                    dofs = [ux uy];
                    nnodes = 4;
                    
                case strcmp(elementName,'SOLID185')
                    dofs = [ux uy uz];
                    nnodes = 8;
                    
                case strcmp(elementName,'SOLID186')
                    dofs = [ux uy uz];
                    nnodes = 20;
                    
                case strcmp(elementName,'SOLID187')
                    dofs = [ux uy uz];
                    nnodes = 10;
                    
                otherwise
                    msg = ['AnsysInput: Available dofs for element ', ...
                        elementName, ' not defined.'];
                    e = MException('MATLAB:bm_mfem:undefinedElement',msg);
                    throw(e);
            end
        end
        
        function A = readCoord()
            % function A = readCoord()
            %
            % Function   : readCoord
            %
            % Description: This function gets the nodes coordinates from txt files
            %              created in ANSYS
            %
            % Parameters :
            %
            % Return     : A                   - matrix with nodal information
            %
            fid=fopen('DataAnsys/nodeCoor.txt') ;
            fidd=fopen('DataAnsys/nodeCoor_modified.dat','w') ;
            if fid < 0, error('Cannot open file'); end
            % Discard some line to read the data from the txt files
            for j = 1 : 13
                fgetl(fid) ;
            end
            
            while ~feof(fid)
                tline=fgets(fid);
                if isspace(tline)
                    for j = 1 : 9
                        fgetl(fid) ;
                    end
                else
                    fwrite(fidd,tline) ;
                end
            end
            
            fclose all ;
            filename = 'DataAnsys/nodeCoor_modified.dat';
            delimiterIn = ' ';
            % Get data in matlab
            A = importdata(filename,delimiterIn);
        end
        
        function [elementList,nodesArrays,nodeConnectivity] = readElements()
            % function [elementList,nodesArrays] = readElements()
            %
            % Function   : readElements
            %
            % Description: This function gets the element information from the txt
            %              files generated by ANSYS
            %
            % Parameters :
            %
            % Return     : elementList  - cell array with element names in
            %                             elementList{:,1} and keyopts in
            %                             elementList{:,2}
            %              nodesArrays  - cell array with the nodes related
            %                             to the elements in the model.
            %                             nodesArrays{i} are all node
            %                             numbers for the element i
            %              nodeConnectivity - cell array with all nodes for
            %                             each element. nodeConnectivity{i}
            %                             is the node array for element i
            
            % read element types with their keyopts
            fid=fopen('DataAnsys/elemTyp.txt');
            fgetl(fid);
            tline = fgetl(fid);
            tmp = strsplit(strtrim(tline),' ');
            elementList = cell(str2double(tmp{7}),2);    %array for element type and keyopts
            tline = fgetl(fid);
            
            while ~ feof(fid)
                if contains(tline,'ELEMENT TYPE')
                    tmp = strsplit(strtrim(tline),' ');
                    if strcmp(tmp{4},'THROUGH')
                        tmp = str2double(tmp);
                        tmp(isnan(tmp)) = [];
                        for ii = tmp(1):tmp(2)
                            elementList{ii,1} = elementList{tmp(3),1};
                            elementList{ii,2} = elementList{tmp(3),2};
                        end
                    elseif strcmp(tmp{5},'THE')
                        tmp = str2double(tmp);
                        tmp(isnan(tmp)) = [];
                        elementList{tmp(1),1} = elementList{tmp(2),1};
                        elementList{tmp(1),2} = elementList{tmp(2),2};
                    else
                        n_etype = str2double(tmp{3});
                        elementList{n_etype,1} = tmp{5};
                        keyopts = zeros(1,18);
                        for ii = 0:2
                            tline = fgetl(fid);
                            tmp = str2double(strsplit(strtrim(tline),' '));
                            keyopts(ii*6+1:ii*6+6) = tmp(end-5:end);
                        end
                        elementList{n_etype,2} = keyopts;
                    end
                end
                tline = fgetl(fid);
            end
            fclose(fid);
            
            % Read elements with their nodes
            % remove stuff from element list and save it
            fid=fopen('DataAnsys/elemNodes.txt') ;
            fidd=fopen('DataAnsys/elemNodes_modified.dat','w') ;
            if fid < 0, error('Cannot open file'); end
            % Discard some line to read the data from the txt files
            for j = 1 : 13
                fgetl(fid) ;
            end
            while ~feof(fid)
                tline=fgets(fid);
                if isspace(tline)
                    for j = 1 : 10
                        fgetl(fid) ;
                    end
                else
                    fwrite(fidd,tline) ;
                end
            end
            fclose all ;
            
            % read element data
            eledat = sscanf(fileread('DataAnsys/elemNodes_modified.dat'),'%u');
            nodesArrays = cell(size(elementList,1),1);
            nodeConnectivity = cell(0);
            
            ii = 1;
            while ii < length(eledat)
                etype = eledat(ii+2);
                [~, nnodes] = AnsysInput.getAnsysElementInfo(elementList{etype,1});
                nodes = eledat(ii+6:ii+5+nnodes);
                nodesArrays{etype}(end+1:end+length(nodes)) = nodes;
                ii = ii+6+nnodes;
                
                nodeConnectivity{end+1} = nodes; %#ok<AGROW>
            end
            
            for ii = 1:size(elementList,1)
                nodesArrays{ii} = unique(nodesArrays{ii});
            end
            
        end
        
        function nodeNum = readRecord_5()
            % function nodeNum = readRecord_5()
            %
            %
            % Function   : readRecord_5
            %
            % Description: This function get the nodal equivalence between the
            %              original number of node given in ANSYS and the distribution
            %              within the stiffness matrix through reading record5
            %
            % Parameters :
            %
            % Return     : nodeNum                   - array
            %
            fid = fopen('DataAnsys/record_5.txt', 'r') ;
            if fid < 0, error('Cannot open file'); end
            for i = 1 : 10
                fgetl(fid) ;
            end
            buffer = fread(fid, Inf) ;
            fclose(fid);
            fid = fopen('DataAnsys/record_5_modified.txt', 'w')  ;
            fwrite(fid, buffer) ;
            fclose(fid) ;
            filename = 'DataAnsys/record_5_modified.txt';
            delimiterIn = ' ';
            A = importdata(filename,delimiterIn);
            %wenn nur ein Element in FEmodel dann ist A kein struct
            if ~isstruct(A)
                B.textdata=strtrim(cellstr(num2str(A'))');
                A=B;
            else
                A.textdata(:,6)=[];
            end
            nodeNum = [];
            for i = 1 : size(A.textdata,1)
                %for j = 1 : 5
                for j = 1 : size(A.textdata,2)
                    if isnan(str2double(A.textdata(i,j)))
                        break;
                    end
                    nodeNum = [nodeNum str2double(A.textdata(i,j))]; %#ok<AGROW>
                end
            end
        end
        
        function A = readRestrictions()
            % function A = readRestrictions()
            %
            % Function   : readRestrictions
            %
            % Description: This function get the restrictions on the coordinates from
            %              ANSYS
            %
            % Parameters :
            %
            % Return     : A cell with restrictions.
            %               A{1}: node numbers
            %               A{2}: resticted dof name
            %               A{3}: real values the dof is restricted to
            %               A{4}: imaginary values the dof is restricted to
            
            fid = fopen('DataAnsys/nodeRest.txt');
            fidd=fopen('DataAnsys/nodeRest_modified.dat','w') ;
            if fid < 0, error('Cannot open file'); end
            
            % Discard some lines to read the data from the txt files
            for j = 1 : 13
                fgetl(fid) ;
            end
            while ~feof(fid)
                tline=fgets(fid);
                if isspace(tline)
                    for j = 1 : 9
                        fgetl(fid) ;
                    end
                else
                    fwrite(fidd,tline) ;
                end
            end
            fclose all;
            
            fid=fopen('DataAnsys/nodeRest_modified.dat') ;
            
            A = textscan(fid,'%u%s%f%f');
            
            for ii = 1:length(A{2})
                A{2}{ii} = AnsysInput.replaceANSYSDofName(A{2}{ii});
            end
            
        end
        
        function A = readLoads()
            % function A = readLoads()
            %
            % Function   : readLoads
            %
            % Description: This function gets the loads on coordinates from
            %              ANSYS
            %
            % Parameters :
            %
            % Return     : A cell with loads.
            %               A{1}: node numbers
            %               A{2}: resticted dof name
            %               A{3}: real values the dof is restricted to
            %               A{4}: imaginary values the dof is restricted to

            fid = fopen('DataAnsys/nodeLoads.txt');
            fidd=fopen('DataAnsys/nodeLoads_modified.dat','w') ;
            if fid < 0, error('Cannot open file'); end
            
            % Discard some lines to read the data from the txt files
            for j = 1 : 13
                fgetl(fid) ;
            end
            while ~feof(fid)
                tline=fgets(fid);
                if isspace(tline)
                    for j = 1 : 9
                        fgetl(fid) ;
                    end
                else
                    fwrite(fidd,tline) ;
                end
            end
            fclose all;
            
            fid=fopen('DataAnsys/nodeLoads_modified.dat') ;
            
            A = textscan(fid,'%u%s%f%f');
            
            for ii = 1:length(A{2})
                A{2}{ii} = AnsysInput.replaceANSYSDofName(A{2}{ii});
            end
            
        end
        
        function A = readSurfaceLoads(nodeCoords)
            % function A = readSurfaceLoads()
            %
            % Function   : readSurfaceLoads
            %
            % Description: This function gets the loads on surfaces from
            %              ANSYS
            %
            % Parameters :
            %
            % Return     : An array with surface loads:
            %              A[:,1]: node numbers
            %              A[:,2]: real part of load
            %              A[:,3]: imaginary part of load
            %              A[:,4:6]: normal of the surface the load is
            %              acting on

            fid = fopen('DataAnsys/nodeSurfaceLoads.txt');
            if fid < 0, error('Cannot open file'); end
            
            A = zeros(0,6);
            faceNodes = [];
            
            % Discard some lines to read the data from the txt files
            for j = 1 : 13
                fgetl(fid) ;
            end
            while ~feof(fid)
                tline=fgets(fid);
                if isspace(tline)
                    for j = 1 : 10
                        fgetl(fid) ;
                    end
                end
                tmp = str2double(strsplit(strtrim(tline),' '));
                if length(tmp) == 3
                    A(end+1,1:3) = tmp; %#ok<AGROW>
                    faceNodes(end+1) = tmp(1); %#ok<AGROW>
                elseif length(tmp) == 5
                    A(end+1,1:3) = tmp(3:5); %#ok<AGROW>
                    if ~isempty(faceNodes)
                        n1 = nodeCoords(faceNodes(1),2:4);
                        n2 = nodeCoords(faceNodes(2),2:4);
                        n3 = nodeCoords(faceNodes(3),2:4);
                        normal = cross(n2-n1,n3-n1);
                        A(end-4:end-1,4:6) = ones(4,1)*(normal/norm(normal));
                    end
                    faceNodes = tmp(3);
                end
            end
            fclose all;
            
        end
        
        function readErrorLog(printWarnings)
            fid = fopen('file.err');
            while ~feof(fid)
                tline=fgetl(fid);
                if contains(tline,'WARNING') && printWarnings
                    tline=fgetl(fid);
                    msg = "";
                    while ~all(isspace(tline))
                        msg = msg + string(tline);
                        tline=fgetl(fid);
                        if feof(fid); break; end
                    end
                    warning(char(msg))
                elseif contains(tline,'ERROR')
                    tline=fgetl(fid);
                    msg = "";
                    while ~all(isspace(tline))
                        msg = msg + string(tline);
                        tline=fgetl(fid);
                        if feof(fid); break; end
                    end
                    err = MException('MATLAB:bm_mfem:ansysError',char(msg));
                    fclose all;
                    delete('file.err');
                    throw(err);
                end
            end
            fclose all;
            delete('file.err');
        end
        
        function name = replaceANSYSDofName(ansysName)
            switch ansysName
                case {'UX', 'FX'}
                    name = 'DISPLACEMENT_X';
                case {'UY', 'FY'}
                    name = 'DISPLACEMENT_Y';
                case {'UZ', 'FZ'}
                    name = 'DISPLACEMENT_Z';
                case 'ROTX'
                    name = 'ROTATION_X';
                case 'ROTY'
                    name = 'ROTATION_Y';
                case 'ROTZ'
                    name = 'ROTATION_Z';
                otherwise
                    msg = ['AnsysInput: Unknown ANSYS dof name ', ansysName];
                    err = MException('MATLAB:bm_mfem:invalidArguments',msg);
                    throw(err);
            end
        end
        
    end
    
end

