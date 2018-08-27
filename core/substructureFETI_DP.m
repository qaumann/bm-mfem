classdef substructureFETI_DP < handle
    
   %% properties
   properties (Access=private)
       nodematrix=Node.empty  %Matrix der Knoten ids
       nodearray=Node.empty
       K        % cell array, speichert die Knoten ids jeder Substruktur
       bc
       br
       in
       gbc
       gbr
       gin
   end
   
   
   
   %% test and constructor
   methods
       
       function substructuring= substructureFETI_DP(femModel)
             if (nargin > 0)
                
            else
                error('input model is missing');
            end
       end
       
   end
   
   
  %% methods
   methods (Static)
       
       %% nodematrix
       function [nodematrix]=setupNodeMatrix(femModel,dim)
       nodearray=femModel.getAllNodes;
       nodeIdArray=zeros(length(nodearray));
       for itnod = 1:length(nodearray)
           nodeIdArray(itnod)=nodearray(itnod).getId;
       end
       nodematrix=zeros(size(dim));
       %nodematrix=Node.empty;
       k=1;
       for i=1:dim(2)
           for j=1:dim(1)
           %nodematrix(j,i)=nodearray(k);
           nodematrix(j,i)=nodeIdArray(k);
           k=k+1;
           end
       end
       end
       
       
       %% Unterteilung der nodematrix in Substrukturen Kij
       % Sortierung der Vektoren bc, br, in
       
       function [K,bc,br,in,gbc,gbr,gin]= substructureNodeMatrix(femModel,nodematrix,Ns,v,hz,dim)
           
           if hz*v~=Ns
                fprintf('unzul�ssige Substrukturierung, bitte Anzahl und Unterteilung der Substrukturen �berpr�fen')
                return
           elseif Ns==1
                fprintf('keine Substrukturierung ausgew�hlt bitte Ns ungleich 1 w�hlen')
                return
           else
               
            K=cell(v,hz); %cell um die verschiedenen Substructures als arrays darin zu speichern
            a=floor(size(nodematrix,1)/v); %Anzahl Knoten einer Spalte einer Substtruktur, Zeilenanzahl
            b=floor(size(nodematrix,2)/hz); %%Anzahl Knoten einer Zeile einer Substtruktur, Spaltenanzahl
            bc=cell(v,hz);
            br=cell(v,hz);
            in=cell(v,hz);
            gbc=[];
            gbr=[];
            gin=[];
            
            if or(a<2,b<2)
                fprintf('Substrukturierung erzeugt zu kleine Substrukturen, bitte kleinere Anzahl an Substrukturen w�hlen!');
            return
            else
            n=1;
            for i=1:hz
                for j=1:v
                       if i==1 && j==1 %Fall 1: linke obere Ecke
                       if v==1 %falls nur eine Substruktur in vertikale Richtung vorhanden ist
                                bc(j,i)={[nodematrix(1,b+1);nodematrix(a,b+1)]};
                                br(j,i)={nodematrix(2:a-1,b+1)};
                                K(j,i)={nodematrix((j-1)*a+1:j*a,(i-1)*b+1:i*b+1)};
                       else
                                bc(j,i)={[nodematrix(a+1,1);nodematrix(1,b+1);nodematrix(a+1,b+1)]};
                                br(j,i)={[nodematrix(a+1,2:b);nodematrix(2:a,b+1)]};
                                K(j,i)={nodematrix((j-1)*a+1:j*a+1,(i-1)*b+1:i*b+1)};
                        end
                        elseif i==1 && j~=1 && j~=v %Fall 2: erste Spalte Mitte
                            bc(j,i)={[nodematrix((j-1)*a+1,1);nodematrix((j-1)*a+1,b+1);nodematrix(j*a+1,1);nodematrix(j*a+1,b+1)]};
                            br(j,i)={[nodematrix((j-1)*a+1,2:b).';nodematrix(j*a+1,2:b).';nodematrix((j-1)*a+2:j*a,b+1)]};
                            K(j,i)={nodematrix((j-1)*a+1:j*a+1,(i-1)*b+1:i*b+1)};
                        elseif i==1 && j==v %Fall 3 linke untere Ecke
                            bc(j,i)={[nodematrix(dim(1)-(a),1);nodematrix(dim(1)-a,b+1);nodematrix(dim(1),b+1)]};
                            br(j,i)={[nodematrix(dim(1)-a,2:b);nodematrix(dim(1)-a+1:dim(1)-1,b+1)]};
                            K(j,i)={nodematrix((j-1)*a+1:dim(1),(i-1)*b+1:i*b+1)};  
                        elseif j==1 && i~=1 && i~= hz    %Fall 4 erste Zeile Mitte
                            if v==1 %falls nur eine Substruktur in vertikale Richtung vorhanden ist
                                bc(j,i)={[nodematrix(1,(i-1)*b+1);nodematrix(a,(i-1)*b+1);nodematrix(1,i*b+1);nodematrix(a,i*b+1)]};
                                br(j,i)={[nodematrix(2:j*a-1,(i-1)*b+1);nodematrix(2:j*a-1,i*b+1)]};
                                K(j,i)={nodematrix((j-1)*a+1:j*a,(i-1)*b+1:i*b+1)};
                            else
                                bc(j,i)={[nodematrix((j-1)*a+1,(i-1)*b+1);nodematrix(j*a+1,(i-1)*b+1);nodematrix((j-1)*a+1,i*b+1);nodematrix(j*a+1,i*b+1)]};
                                br(j,i)={[nodematrix(2:j*a,(i-1)*b+1);nodematrix(a+1,(i-1)*b+2:i*b).';nodematrix(2:j*a,i*b+1)]};
                                K(j,i)={nodematrix((j-1)*a+1:j*a+1,(i-1)*b+1:i*b+1)};
                            end
                        elseif i>1 && i<hz && j>1 && j<v %Fall 5 Mitte Mitte
                            bc(j,i)={[nodematrix((j-1)*a+1,(i-1)*b+1);nodematrix(j*a+1,(i-1)*b+1);nodematrix((j-1)*a+1,i*b+1);nodematrix(j*a+1,i*b+1)]};
                            br(j,i)={[nodematrix((j-1)*a+2:j*a,(i-1)*b+1);nodematrix((j-1)*a+1,(i-1)*b+2:i*b).';nodematrix(j*a+1,(i-1)*b+2:i*b).';nodematrix((j-1)*a+2:j*a,i*b+1)]};
                            K(j,i)={nodematrix((j-1)*a+1:j*a+1,(i-1)*b+1:i*b+1)};
                        elseif j==v && i~=1 && i~= hz %Fall 6 unterste Zeile Mitte
                            bc(j,i)={[nodematrix((j-1)*a+1,(i-1)*b+1);nodematrix(dim(1),(i-1)*b+1);nodematrix((j-1)*a+1,i*b+1);nodematrix(dim(1),i*b+1)]};
                            br(j,i)={[nodematrix((j-1)*a+2:dim(1)-1,(i-1)*b+1);nodematrix((j-1)*a+1,(i-1)*b+2:i*b).';nodematrix((j-1)*a+2:dim(1)-1,i*b+1)]};
                            K(j,i)={nodematrix((j-1)*a+1:dim(1),(i-1)*b+1:i*b+1)};
                        elseif j==1 && i==hz %Fall 7 rechte obere Ecke
                            if v==1 %falls nur eine Substruktur in vertikale Richtung vorhanden ist
                                bc(j,i)={[nodematrix(1,dim(2)-b);nodematrix(a,dim(2)-b)]};
                                br(j,i)={nodematrix(2:a-1,dim(2)-b)};
                                K(j,i)={nodematrix((j-1)*a+1:j*a,(i-1)*b+1:dim(2))};
                            else
                                bc(j,i)={[nodematrix(1,dim(2)-b);nodematrix(a+1,dim(2)-b);nodematrix(a+1,dim(2))]};
                                br(j,i)={[nodematrix(2:a,dim(2)-b);nodematrix(a+1,dim(2)-b+1:dim(2)-1).']};
                                K(j,i)={nodematrix((j-1)*a+1:j*a+1,(i-1)*b+1:dim(2))};
                            end
                        elseif i==hz && j~=1 && j~=v %Fall 8 letzte Spalte Mitte
                            bc(j,i)={[nodematrix((j-1)*a+1,(i-1)*b+1);nodematrix(j*a+1,(i-1)*b+1);nodematrix((j-1)*a+1,dim(2));nodematrix(j*a+1,dim(2))]};
                            br(j,i)={[nodematrix((j-1)*a+2:j*a,(i-1)*b+1);nodematrix((j-1)*a+1,dim(2)-b+1:dim(2)-1).';nodematrix(j*a+1,dim(2)-b+1:dim(2)-1).']};
                            K(j,i)={nodematrix((j-1)*a+1:j*a+1,(i-1)*b+1:dim(2))};
                        else %Fall 9 rechte untere Ecke
                            bc(j,i)={[nodematrix((j-1)*a+1,(i-1)*b+1);nodematrix(dim(1),(i-1)*b+1);nodematrix((j-1)*a+1,dim(2))]};
                            br(j,i)={[nodematrix((j-1)*a+2:dim(1)-1,dim(2)-b);nodematrix(dim(1)-a,(dim(2)-b+1:dim(2)-1)).']};
                            K(j,i)={nodematrix((j-1)*a+1:dim(1),(i-1)*b+1:dim(2))};
                        end
                        in(j,i)={setdiff(cell2mat(K(j,i)),union(cell2mat(bc(j,i)),cell2mat(br(j,i))))};
                       
                        
                        gbc1=cell2mat(bc(j,i));
                        gbr1=cell2mat(br(j,i));
                        gin1=cell2mat(in(j,i));
                        
                        %size (gbc1...) l�uft als Variable mit
                        
                        gbc(size(gbc,1)+1:size(gbc,1)+size(gbc1,1),1)=gbc1;  %globaler Vektor der Eckknoten
                        gbr(size(gbr,1)+1:size(gbr,1)+size(gbr1,1),1)=gbr1;  %globaler Vektor der interface Knoten
                        gin(size(gin,1)+1:size(gin,1)+size(gin1,1),1)=gin1;  % globaler Vektor der internen Knoten
                        n=n+1;
                 end
            end
            end   
           end
       end      
            
       %% Zusammenbauen der Steifigkeitsmatrix jeder Substruktur
      
       %Knotenarray jeder Substruktur:
       function [sNodeIdArray] = getSubstructureNodeIdArray(K,v,hz)
            for i=1:hz
                for j=1:v
                    matrix=cell2mat(K(j,i));
                    sNodeIdArray(j,i)={matrix(:)};                  
                end
            end
           
       end
       
       %lege die Knoten des FemModels auf die Stelle der Id in K ab
       function [sNodeArray] = getSubstructureNodeArray(femModel,sNodeIdArray,K,v,hz)
           for i=1:hz
                for j=1:v
                   sNodeArray(j,i)={femModel.getNodes(cell2mat(sNodeIdArray(j,i)))};                  
                end
           end    
       end
       
       %element array jeder Substruktur  Anm: Id Aufruf mit: sElementArray{1,3}.getId
       function [sElementArray,id,nodes] = getSubstructureElementArray(femModel,sNodeArray,sNodeIdArray,K,v,hz)
           elements=femModel.getAllElements;
           array=elements.empty;
           c=1;
           for itEle = 1:length(elements)
                nodes(c:c+1,1)=elements(itEle).getNodes; %nodematrix, sortnodematrix?
                id(itEle)=elements(itEle).getId;
                c=c+2;
           end
           
           for i=1:hz
                for j=1:v
                    k=1;
                    c=1;
                    for itEle=1:length(id)
                    if (find(cell2mat(sNodeIdArray(j,i)) == nodes(c).getId)>0) &(find(cell2mat(sNodeIdArray(j,i)) == nodes(c+1).getId)>0)                   
                        array(k)=femModel.getElement(id(itEle)); 
                        k=k+1;
                    end
                    c=c+2;
                    end
                    sElementArray(j,i)={array};
                end
           end
           
       end
       
       %dof array jeder Substruktur:
       function [sDofArray]= getSubstrucureDofArray(femModel,sNodeIdArray,sNodeArray,sElementArray,K,v,hz)
           %sDofArray=Dof.empty;
           list=Dof.empty;
           array=Dof.empty;
           for i=1:hz
                for j=1:v
                    array=sNodeArray{j,i};
                    c=1;
                    for k=1:length(array)
                    list(c:c+1)=array(k).getDofArray; 
                    c=c+2;
                    end
                    sDofArray{j,i}=list;
                end
           end
       end
   
       %Steifigkeitsmatrix jeder Substruktur
       function [gstiffnessMatrix, greducedStiffnessMatrix] = assembleSubstructureStiffnessMatrix(femModel,sElementArray,sDofArray,v,hz)        
           for i=1:hz
                for j=1:v
            elements = sElementArray{j,i};
            ndofs = length(sDofArray{j,i});
            stiffnessMatrix = zeros(ndofs);

            for itEle = 1:length(elements)
               elementalStiffnessMatrix = elements(itEle).computeLocalStiffnessMatrix;
               %elementalDofIds= sDofArray{j,i}.getId;   %lokale dof ids eines Elements in einer substruktur beginnt bei 1
               elementalDofIds = elements(itEle).getDofList().getId;
               for l=1:4
               localId(l)=find(sDofArray{j,i}.getId==elementalDofIds(l));
               end
               %stiffnessMatrix(elementalDofIds, elementalDofIds) = ...
               %stiffnessMatrix(elementalDofIds, elementalDofIds) + elementalStiffnessMatrix;
               stiffnessMatrix(localId, localId) = ...
               stiffnessMatrix(localId, localId) + elementalStiffnessMatrix;
            end
            gstiffnessMatrix{j,i}=stiffnessMatrix;
            
            [~, fixedDofs] = femModel.getDofConstraints;
            if ~ isempty(fixedDofs)
                fixedDofIds = fixedDofs.getId();
                sFixedDofId=[];
                %local id wie oben
                c=1;
                for k=1:length(fixedDofIds)
                    if find(sDofArray{j,i}.getId==fixedDofIds(k))>0
                        sFixedDofId(c)=fixedDofIds(k);
                        c=c+1;
                    end
                    
                end
                if ~ isempty(sFixedDofId)
                for d=1:length(sFixedDofId)
                    localFixedDofId(d)=find(sDofArray{j,i}.getId==sFixedDofId(d));
                end
                
                reducedStiffnessMatrix = applyMatrixBoundaryConditions(gstiffnessMatrix{j,i},localFixedDofId ); 
                greducedStiffnessMatrix{j,i}=reducedStiffnessMatrix;
                else
                greducedStiffnessMatrix{j,i}=gstiffnessMatrix{j,i};
                end
            end
            end
        end
       end
       
       %% Zerlegung der Steifigkeitsmatrizen jeder Substruktur: Umsortierung nach i,br,bc
       function [Ksort,Krr,Kcc,Krc,Kcr]=splitMatrix(femModel,gstiffnessMatrix,sDofArray,v,hz,in,br,bc)
           for i=1:hz
                for j=1:v
                    %setup der Dofs der corner und reminder Knoten,
                    %globalen und lokale Dofs
                    %Knoten Id vektoren
                    u=[]
                    r=[]
                    un=Node.empty
                    rn=Node.empty
                    udof=Dof.empty
                    rdof=Dof.empty
                    
                    u=[in{j,i};br{j,i};bc{j,i}]
                    r=[in{j,i};br{j,i}]
                    %Knotenvektoren
                    un=femModel.getNodes(u)
                    rn=femModel.getNodes(r)
                    %DofVektoren
                    c=1;
                    for k=1:length(un)
                    udof(c:c+1)=un(k).getDofArray
                    c=c+2;
                    end
                    d=1;
                    for l=1:length(rn)
                    rdof(d:d+1)=rn(l).getDofArray
                    d=d+2;
                    end
                    %DofIdVektoren globale dof Benennung
                    uDofId=Dof.empty
                    rDofId=Dof.empty
                    uDofId=udof.getId
                    rDofId=rdof.getId
                    
                    
                    %festgehaltene Dofs entfernen  %fixed dofs sind global
                    %benannt!!!!
                    [freeDofs, fixedDofs] = femModel.getDofConstraints
                    if ~ isempty(fixedDofs)
                    fixedDofIds = fixedDofs.getId()
                    c=1;
                    for k=1:length(fixedDofIds)
                    if find(sDofArray{j,i}.getId==fixedDofIds(k))>0
                        sFixedDofId(c)=fixedDofIds(k)
                        c=c+1;
                    end
                    end
                    end
                    if ~ isempty(sFixedDofId)
                    n=length(uDofId)
                    m=length(rDofId)
                    c=1
                    for k=1:n
                        for l=1:length(sFixedDofId)
                            if c>length(sFixedDofId)
                                break
                            else
                        if uDofId(k)==sFixedDofId(l)
                        uDofId(k)=[]
                        c=c+1;
                        end
                            end
                        end
                    end
                    c=1
                    for k=1:m
                       for l=1:length(sFixedDofId)
                           if c>length(sFixedDofId)
                                break
                           else
                       if rDofId(k)==sFixedDofId(l)
                        rDofId(k)=[]
                        c=c+1
                       end 
                           end
                       end
                    end
                    end
                   

                    %DofIdVektoren lokale dof Benennung innerhalb einer
                    %Substruktur, fixed dofs sind weg, Benneung startet
                    %wieder bei 1, Umbenennen der dofs
                    uDofIdLoc=[];
                    rDofIdLoc=[];
                    for m=1:length(uDofId)
                    uDofIdLoc(m)=find(sDofArray{j,i}.getId==uDofId(m))
                    end
                        %rdof lokal hat als element 11 und 12 die eintr�ge 14,15 als lok. Fg
                        %vorsicht bei Iteration!
                    for n=1:length(rDofId)
                    rDofIdLoc(n)=find(sDofArray{j,i}.getId==rDofId(n))
                    end
                    
                    %Neubennenung der reduzierten Vektoren: Versuch �ber
                    %die Stiefikeitsmatrix geht nicht neuer versuc!
%                     helpVektoru=[1:length(uDofIdLoc)];
%                     helpVektorr=[1:length(rDofIdLoc)];
%                     for n=1:length(uDofIdLoc)
%                         uDofIdLocSort(i)=
%                  
                    %Umsortierte Stiefigkeitsmatrix
                    n=length(uDofIdLoc)
                    %Ksort=Node.empty;
                    Kmatrix=gstiffnessMatrix{j,i}
                    for k=1:n
                        for l=1:n
                            Ksort(k,l)=Kmatrix(uDofIdLoc(k),uDofIdLoc(l));
                        end
                    end
                    %Steifigkeitsmatrix der remainder (br und i): Krr
                    %Krr=string(zeros(size(r,1)));
                    Krr{j,i}=Ksort(1:size(r,1),1:size(r,1));
                    %Steifigkeitsmatrix der corner Freiheitsgrade (bc):Kcc
                    %Kcc=string(zeros(size(bc,1)));
                    Kcc{j,i}=Ksort(size(r,1)+1:size(r,1)+size(bc,1),size(r,1)+1:size(r,1)+size(bc,1));
                    %Steifigkeitsmatrizen der Kombinierten Freiheitsgrade rbc, bcr: Krc, Kcr
                    Krc{j,i}=Ksort(1:size(r,1),size(r,1)+1:size(Ksort,1));
                    Kcr{j,i}=Ksort(size(r,1)+1:size(Ksort,1),1:size(r,1));
                end
           end
       end
       
       
       
       

       %% Verdopplung und Neubenneung der br Knoten und interface Elemente, speichern der neuen infos im femModel
       
        function [doubleNodes]= getDoubleNodes(femModel,gbr)
           
            gsort=sort(gbr);
            k=1;
            for i=1:2:length(gsort)
                if any(gsort,gsort(i))==1
                    doubleNodes(k)=gsort(i);
                    k=k+1;
                end
            end
        end
        
%         function [nodearray]=doubleTheNodes(femModel,gbr)
%             nodearray=femModel.getAllNodes;
%             for i=1:length(nodearray)
%                 if any(nodearray(i),gbr)
%                 end
%             end
%                 
%            
%             
%         end
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
       
   end
end