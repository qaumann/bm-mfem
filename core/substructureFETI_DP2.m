classdef substructureFETI_DP2 < handle
    
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
       
       function substructuring= substructureFETI_DP(~)
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
       
       function [K,bc,br,in,gbc,gbr,gin]= substructureNodeMatrix(nodematrix,Ns,v,hz,dim)
           
           if hz*v~=Ns
                fprintf('unzul�ssige Substrukturierung, bitte Anzahl und Unterteilung der Substrukturen �berpr�fen')
                return
           elseif Ns==1
                fprintf('keine Substrukturierung ausgew�hlt bitte Ns ungleich 1 w�hlen')
                return
           else
               
            K=cell(v,hz); %cell um die verschiedenen Substructures als arrays darin zu speichern
            a=floor(size(nodematrix,1)/v) %Anzahl Knoten einer Spalte einer Substtruktur, Zeilenanzahl
            b=floor(size(nodematrix,2)/hz) %%Anzahl Knoten einer Zeile einer Substtruktur, Spaltenanzahl
            %Warnung: falls der Rest der Division sehr gro� ist (>0,5)
            %entstehen durch die Abrundung (floor) an den R�ndern Substrukturen mit sehr vielen Knoten
            %(Restknoten), in diesem fall bitte Anzahl der Substruktur
            %�ndern
            if floor(size(nodematrix,1)/v)~=round(size(nodematrix,1)/v) | floor(size(nodematrix,2)/hz)~= round(size(nodematrix,2)/hz)
                fprintf('Warnung: es entstehen an den R�ndern Substrukturen mit vielen Restknoten, bitte Einteilung der Substrukturen �berpr�fen')
            end
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
                            br(j,i)={[nodematrix(a+1,2:b).';nodematrix(2:a,b+1)]};
                            K(j,i)={nodematrix((j-1)*a+1:j*a+1,(i-1)*b+1:i*b+1)};
                        end
                    elseif i==1 && j~=1 && j~=v %Fall 2: erste Spalte Mitte
                        bc(j,i)={[nodematrix((j-1)*a+1,1);nodematrix((j-1)*a+1,b+1);nodematrix(j*a+1,1);nodematrix(j*a+1,b+1)]};
                        br(j,i)={[nodematrix((j-1)*a+1,2:b).';nodematrix(j*a+1,2:b).';nodematrix((j-1)*a+2:j*a,b+1)]};
                        K(j,i)={nodematrix((j-1)*a+1:j*a+1,(i-1)*b+1:i*b+1)};
                    elseif i==1 && j==v %Fall 3 linke untere Ecke
                        bc(j,i)={[nodematrix((j-1)*a+1,1);nodematrix((j-1)*a+1,b+1);nodematrix(dim(1),b+1)]};
                        br(j,i)={[nodematrix((j-1)*a+1,2:b).';nodematrix((j-1)*a+2:dim(1)-1,b+1)]};
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
                            bc(j,i)={[nodematrix(1,(i-1)*b+1);nodematrix(a+1,(i-1)*b+1)]};
                            br(j,i)={nodematrix(2:a,(i-1)*b+1)};
                            K(j,i)={nodematrix((j-1)*a+1:j*a,(i-1)*b+1:dim(2))};
                        else
                            bc(j,i)={[nodematrix(1,(i-1)*b+1);nodematrix(a+1,(i-1)*b+1);nodematrix(a+1,dim(2))]};
                            br(j,i)={[nodematrix(2:a,(i-1)*b+1);nodematrix(a+1,(i-1)*b+2:dim(2)-1).']};
                            K(j,i)={nodematrix((j-1)*a+1:j*a+1,(i-1)*b+1:dim(2))};
                        end
                    elseif i==hz && j~=1 && j~=v %Fall 8 letzte Spalte Mitte
                        bc(j,i)={[nodematrix((j-1)*a+1,(i-1)*b+1);nodematrix(j*a+1,(i-1)*b+1);nodematrix((j-1)*a+1,dim(2));nodematrix(j*a+1,dim(2))]};
                        br(j,i)={[nodematrix((j-1)*a+2:j*a,(i-1)*b+1);nodematrix((j-1)*a+1,(i-1)*b+1+1:dim(2)-1).';nodematrix(j*a+1,(i-1)*b+2:dim(2)-1).']};
                        K(j,i)={nodematrix((j-1)*a+1:j*a+1,(i-1)*b+1:dim(2))};
                    else %Fall 9 rechte untere Ecke
                        bc(j,i)={[nodematrix((j-1)*a+1,(i-1)*b+1);nodematrix(dim(1),(i-1)*b+1);nodematrix((j-1)*a+1,dim(2))]};
                        br(j,i)={[nodematrix((j-1)*a+2:dim(1)-1,(i-1)*b+1);nodematrix((j-1)*a+1,((i-1)*b+2:dim(2)-1)).']};
                        K(j,i)={nodematrix((j-1)*a+1:dim(1),(i-1)*b+1:dim(2))};
                    end
               in(j,i)={setdiff(cell2mat(K(j,i)),union(cell2mat(bc(j,i)),cell2mat(br(j,i))))};
                       
                        
                        gbc1=cell2mat(bc(j,i));
                        gbr1=cell2mat(br(j,i));
                        gin1=cell2mat(in(j,i));
 
                        
                        %size (gbc1...) l�uft als Variable mit
                        
                        gbc(size(gbc,1)+1:size(gbc,1)+size(gbc1,1),1)=gbc1;  % globaler Vektor der Eckknoten
                        gbr(size(gbr,1)+1:size(gbr,1)+size(gbr1,1),1)=gbr1;  % globaler Vektor der interface Knoten
                        gin(size(gin,1)+1:size(gin,1)+size(gin1,1),1)=gin1;  % globaler Vektor der internen Knoten   
                end
            end
                   

           end
        end
    end   
          
            
       %% Zusammenbauen der Steifigkeitsmatrix jeder Substruktur
      
       %Knotenarray jeder Substruktur:
       function [sNodeIdArray] = getSubstructureNodeIdArray(K,v,hz)
            sNodeIdArray=cell(v,hz);
            for i=1:hz
                for j=1:v
                    matrix=cell2mat(K(j,i));
                    sNodeIdArray(j,i)={matrix(:)};                  
                end
            end
           
       end
       
       %lege die Knoten des FemModels auf die Stelle der Id in K ab
       function [sNodeArray] = getSubstructureNodeArray(femModel,sNodeIdArray,v,hz)
           sNodeArray=cell(v,hz);
           for i=1:hz
                for j=1:v
                   sNodeArray(j,i)={femModel.getNodes(cell2mat(sNodeIdArray(j,i)))};                  
                end
           end    
       end
       
       %element array jeder Substruktur  Anm: Id Aufruf mit: sElementArray{1,3}.getId
       function [sElementArray,id,nodes] = getSubstructureElementArray(femModel,sNodeIdArray,v,hz)
           elements=femModel.getAllElements;
           array=elements.empty;
           c=1;
           id=zeros(length(elements),2);
           for itEle = 1:length(elements)
                nodes(c:c+1,1)=elements(itEle).getNodes; %nodematrix, sortnodematrix?
                id(itEle)=elements(itEle).getId;
                c=c+2;
           end
           
           sElementArray=cell(v,hz);
           for i=1:hz
                for j=1:v
                    array=elements.empty;
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
       function [sDofArray]= getSubstrucureDofArray(sNodeArray,v,hz)
           sDofArray=cell(v,hz);
           list=Dof.empty;

           for i=1:hz
                for j=1:v
                    list=Dof.empty;
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
       function [gstiffnessMatrix, greducedStiffnessMatrix] = assembleSubstructureStiffnessMatrix(femModel,sElementArray,sDofArray,gbr,v,hz)        
           gstiffnessMatrix=cell(v,hz);
           greducedStiffnessMatrix=cell(v,hz);
           br=unique(gbr,'stable');
           for i=1:hz
                for j=1:v
                    elements = sElementArray{j,i};
                    ndofs = length(sDofArray{j,i});
                    stiffnessMatrix = zeros(ndofs);
                    enodes=Node.empty;
                    enodeId=[];
                    for itEle = 1:length(elements)
                       elementalStiffnessMatrix = elements(itEle).computeLocalStiffnessMatrix;
                       
%                    Steifigkeiten der boundry reminder halbieren: 


                       enodes=elements(itEle).getNodes;
                       enodeId=enodes.getId;
                       for g=1:length(enodeId)
                           if find(br==enodeId(g))>0
                               elementalStiffnessMatrix=0.5*elementalStiffnessMatrix;
                           end
                       end
                        
                       
                       
                       
                       %elementalDofIds= sDofArray{j,i}.getId;   %lokale dof ids eines Elements in einer substruktur beginnt bei 1
                       elementalDofIds = elements(itEle).getDofList().getId;
                       localId=zeros(1,4);
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
                                sFixedDofId(c)=fixedDofIds(k);   %nicht Vorbelegen, sfixedDofId muss jede Schleife seine L�nge �ndern!
                                c=c+1;
                            end

                        end
                        if ~ isempty(sFixedDofId)
                            for d=1:length(sFixedDofId)
                                localFixedDofId(d)=find(sDofArray{j,i}.getId==sFixedDofId(d)); %nicht Vorbelegen, localfixedDofId muss jede Schleife seine L�nge �ndern!
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
       function [SortStiffnessmatrix,Krr,Kcc,Krc,Kcr,suDofId,srDofId,suDofIdLoc,srDofIdLoc]=splitMatrix(femModel,gstiffnessMatrix,sDofArray,v,hz,in,br,bc)
           suDofId=cell(v,hz);
           srDofId=cell(v,hz);
           suDofIdLoc=cell(v,hz);
           srDofIdLoc=cell(v,hz);
           SortStiffnessmatrix=cell(v,hz);
           Krr=cell(v,hz);
           Kcc=cell(v,hz);
           Krc=cell(v,hz);
           Kcr=cell(v,hz);
           for i=1:hz
                for j=1:v
                    %setup der Dofs der corner und reminder Knoten,
                    %globalen und lokale Dofs
                    %Knoten Id vektoren
                    u=[];
                    r=[];
                    un=Node.empty;
                    rn=Node.empty;
                    udof=Dof.empty;
                    rdof=Dof.empty;
                    
                    u=[in{j,i};br{j,i};bc{j,i}];
                    r=[in{j,i};br{j,i}];
                    %Knotenvektoren
                    un=femModel.getNodes(u);
                    rn=femModel.getNodes(r);
                    %DofVektoren
                    c=1;
                    for k=1:length(un)
                    udof(c:c+1)=un(k).getDofArray;
                    c=c+2;
                    end
                    d=1;
                    for l=1:length(rn)
                    rdof(d:d+1)=rn(l).getDofArray;
                    d=d+2;
                    end
                    %DofIdVektoren globale dof Benennung
                    uDofId=[];
                    rDofId=[];
                    uDofId=udof.getId;
                    rDofId=rdof.getId;
                    
                    
                    %festgehaltene Dofs entfernen  %fixed dofs sind global
                    %benannt--> substructure fixed dofs identifizieren
                    [~, fixedDofs] = femModel.getDofConstraints;
                    sFixedDofId=[];
                    if ~ isempty(fixedDofs)
                    fixedDofIds = fixedDofs.getId();
                    c=1;
                    for k=1:length(fixedDofIds)
                    if find(sDofArray{j,i}.getId==fixedDofIds(k))>0
                        sFixedDofId(c)=fixedDofIds(k);  
                        c=c+1;
                    end
                    end
                    end
                    if ~ isempty(sFixedDofId)
                    n=length(uDofId);
                    m=length(rDofId);
                    %c=1;
                    for c=1:length(sFixedDofId)
                    uDofId(find(uDofId==sFixedDofId(c)))=[];
                    rDofId(find(rDofId==sFixedDofId(c)))=[];
                    end
                    end
%                     for k=1:n
%                         for l=1:length(sFixedDofId)
%                             if c>length(sFixedDofId)
%                                 break
%                             else
%                         if uDofId(k)==sFixedDofId(l)
%                         uDofId(k)=[];  %orginalvektor wird verk�rzt!!!
%                         c=c+1;
%                         end
%                             end
%                         end
%                     end
%                     c=1;
%                     for k=1:m
%                        for l=1:length(sFixedDofId)
%                            if c>length(sFixedDofId)
%                                 break
%                            else
%                        if rDofId(k)==sFixedDofId(l)
%                         rDofId(k)=[];   %orginalvektor wird verk�rzt!!!
%                         c=c+1;
%                        end 
%                            end
%                        end
%                     end
%                     end
                   suDofId{j,i}=uDofId;
                   srDofId{j,i}=rDofId;

                    %DofIdVektoren lokale dof Benennung innerhalb einer
                    %Substruktur, fixed dofs sind weg, Benennung startet
                    %wieder bei 1, Umbenennen der dofs:
                    uDofIdLoc=[];
                    rDofIdLoc=[];
                    for m=1:length(uDofId)
                    uDofIdLoc(m)=find(sDofArray{j,i}.getId==uDofId(m));
                    end
                    for n=1:length(rDofId)
                    rDofIdLoc(n)=find(sDofArray{j,i}.getId==rDofId(n));
                    end
                    suDofIdLoc{j,i}=uDofIdLoc;
                    srDofIdLoc{j,i}=rDofIdLoc;
        
                    %Umsortierte Steifigkeitsmatrix
                    n=length(uDofIdLoc);
                    Ksort=zeros(n);
                    Kmatrix=gstiffnessMatrix{j,i};
                    for k=1:n
                        for l=1:n
                            Ksort(k,l)=Kmatrix(uDofIdLoc(k),uDofIdLoc(l));
                        end
                    end
                    SortStiffnessmatrix{j,i}=Ksort;
                    r=length(rDofId);
                    l=length(uDofId)-length(rDofId);
                    %Steifigkeitsmatrix der remainder (br und i): Krr
                    Krr{j,i}=Ksort(1:r,1:r);
                    %Steifigkeitsmatrix der corner Freiheitsgrade (bc):vKcc
                    Kcc{j,i}=Ksort(r+1:r+l,r+1:r+l);
                    %Steifigkeitsmatrizen der Kombinierten Freiheitsgrade rbc, bcr: Krc, Kcr
                    Krc{j,i}=Ksort(1:r,r+1:r+l);
                    Kcr{j,i}=Ksort(r+1:r+l,1:r);
                    end
                end
          end
  
       
       %% Aufstellen des Lastvektors jeder Substruktur
       function [sForceVector,ubcId]=getSubstructureForceVector(femModel,Assembler,suDofId,gbc,gbr,v,hz)
           [forceVector, reducedforceVector] = Assembler.applyExternalForces(femModel);  %reduced force vector auch abfragbar!!!
           sForceVector=cell(v,hz);
           % Lastvektor an Knoten aufteilen, unterscheiden zwischen 2
           % wertigen und 4 wertigen knoten, mit ubc vergleichen
           nbc=femModel.getNodes(gbc);
           c=1;
           for k=1:length(nbc)
           ubc(c:c+1)=nbc(k).getDofArray;
           c=c+2;
           end
           
           ubcId=ubc.getId; 
           %Dof Ids der Eckknoten jeder Subsdomain, mehrfachvorkommende Dofs!
           %herausfinden an welchen fg eine kraft wirkt, falls einer dieser
           %fg im ubcid vektor vorkommt, anzahl ermitteln und last durch
           %anzahl teilen
           
           for k=1:length(ubcId)
               x=0;
               x=length(find(ubcId==ubcId(k)));  %Mehrfachauffindung!
               if x>0 & ubcId(k)~=0
               forceVector(ubcId(k))=forceVector(ubcId(k))/x;  %Kraft am Knoten durch Wertigkeit des Knotens teilen
               end
               ubcId(find(ubcId==ubcId(k)))=0;
           end
           
           %bei Belastungen auf FG an den br Knoten: Last halbieren:
           nbr=femModel.getNodes(gbr);
           c=1;
           for k=1:length(nbr)
           ubr(c:c+1)=nbr(k).getDofArray;
           c=c+2;
           end 
           ubrId=ubr.getId;
           for k=1:length(ubrId)
               x=0;
               x=length(find(ubrId==ubrId(k)));  %Mehrfachauffindung!
               if x>0 & ubrId(k)~=0
               forceVector(ubrId(k))=forceVector(ubrId(k))/2;  %Kraft am br Dof halbiert
               end
               ubrId(find(ubrId==ubrId(k)))=0;
           end
           
           
           
           for i=1:hz
               for j=1:v 
                   uDofId=suDofId{j,i};
                   sforceVector=zeros(1,length(uDofId));
                   for k=1:length(uDofId)
                   sforceVector(k)=forceVector(uDofId(k)); %f�r jede Substruktur andere L�nge
                   end
                   sForceVector{j,i}=sforceVector;
               end
           end

       end
       
       %% Sortieren des Lastvektors jeder Substruktur in fr und fbc
       %Anm: sForcevector ist schon fertig wie u sortiert, muss nur noch
       %gesplittet werden
       function [gfr,gfbc]= sortSubstructureForceVector(sForceVector,srDofId,v,hz)
           gfr=cell(v,hz);
           gfbc=cell(v,hz);
           for i=1:hz
               for j=1:v
                   n=length(srDofId{j,i});
                   sforceVector=sForceVector{j,i};
                   m=length(sForceVector{j,i});
                   fr=sforceVector(1:n);
                   fbc=sforceVector(n+1:m);  
                   gfr{j,i}=fr;
                   gfbc{j,i}=fbc;
               end
           end
       end
       
       %% subdomain assembling
       %define boolean Matrix Br
       function[Bbr,urId,ur2,sinDofId,sbrDofId]=getInterfaceBooleanMatrix(femModel,in,sDofArray,srDofId,v,hz)
           
           % Aufsetzten von ur aus suDof Id einen Vektor machen: Dofs sind
           % doppelt enthalten!!!
           
           Bbr=cell(v,hz);
           urId=[];
           sinDofId=cell(v,hz);
           
           for i=1:hz
               for j=1:v
                   rDof=srDofId{j,i};
                   n=length(urId);
                   m=length(rDof);
                   urId(n+1:n+m)=rDof;  %alle in und br dofs enthalten, br dofs kommen doppelt vor
               end
           end
           %eliminieren der doppelten br dofs:
           ur2=unique(urId,'stable'); %globaler Vektor aller in und br der substrukturen in der richtigen Reihenfolge nach substrukturen sortiert
          
           for i=1:hz
               for j=1:v

                 lin=femModel.getNodes(in{j,i});
                 indof=Dof.empty;
                    c=1;
                    for k=1:length(lin)
                    indof(c:c+1)=lin(k).getDofArray;
                    c=c+2;
                    end
                    
                    inDofId=indof.getId;
                    sFixedDofId=[];
                    [~, fixedDofs] = femModel.getDofConstraints;
                    if ~ isempty(fixedDofs)
                    fixedDofIds = fixedDofs.getId();
                    c=1;
                    for k=1:length(fixedDofIds)
                    if find(sDofArray{j,i}.getId==fixedDofIds(k))>0
                        sFixedDofId(c)=fixedDofIds(k);
                        c=c+1;
                    end
                    end
                    end
                    
                    if ~ isempty(sFixedDofId)
                    n=length(inDofId);
                    c=1;
                    for c=1:length(sFixedDofId)
                       inDofId(find(inDofId==sFixedDofId(c)))=[];
                    end
                    end
%                     for k=1:n
%                         for l=1:length(sFixedDofId)
%                             if c>length(sFixedDofId)
%                                 break
%                             else
%                         if inDofId(k)==sFixedDofId(l)
%                         inDofId(k)=[];  %Vektor verkleinert sich!!!
%                         c=c+1;
%                         end
%                             end
%                         end
%                     end
%                     end

                 % ur2 nach i und br sortieren!
                 sinDofId{j,i}=inDofId;
               end
           end
           for i=1:hz
                     for j=1:v
                            srdofid=srDofId{j,i};  %globale Freiheitsgradnummern m�ssen in Reihenfolge von ur2 umge�ndert werden
                            %Bsp; ur2=[15 16 23 24] in globalen nummern, dann
                            %enstrpicht 15 der 1 und  24 der 4 usw.
                            sbrDofId=[];
                            t=1;
                     for e=1:length(srdofid)
                         if find (sinDofId{j,i}==srdofid(e))>0
                         else
                         sbrDofId(t)=srdofid(e);  %nicht vorbelegen, f�r jede substruktur andere L�nge
                         t=t+1;
                         end
                     end
                     sgbrDofId{j,i}=sbrDofId;
                     end
           end
                 
            urin=[];
            ubrin=[];
                 for y=1:hz
                     for x=1:v
                         h=length(sinDofId{x,y});
                         urin(length(urin)+1:length(urin)+h)=sinDofId{x,y};
                         urin=unique(urin,'stable');
                         o=length(sgbrDofId{x,y});
                         ubrin(length(ubrin)+1:length(ubrin)+o)=sgbrDofId{x,y};
                         ubrin=unique(ubrin,'stable');
                     end
                 end
                 ur2=[urin.';ubrin.'];
                 
               for i=1:hz
               for j=1:v
                
                 k=length(sinDofId{j,i});
                 m=length(srDofId{j,i});
                 
                 
                 
                 l=m-k;
                 lBr=[zeros(l,k),eye(l,l)];
                
                 % Br in gloales Schema einordnen um assemblen zu k�nnen:
                 %Br^s ur2^s =[0 ubr2^s 0]^T
                 % Schema: [0 lBr 0]^T; 
                 %dimensions:
                 q=size(ur2,1);
                 %w=size(lBr,1);
                 gBr=zeros(q,size(lBr,2));
                 %Lbr am richtigen dof einordnen(global lokal aufpassen)!,
                 %dofs sind in ur doppelt enthalten, in ur2 nur einfach und
                 %beide Male global und richtig sortiert
                 %sbrDof Id bestimmen:
                 sbrdofid=sgbrDofId{j,i};  %globale Freiheitsgradnummern m�ssen in Reihenfolge von ur2 umge�ndert werden
%                  %Bsp; ur2=[15 16 23 24] in globalen nummern, dann
%                  %enstrpicht 15 der 1 und  24 der 4 usw.
%                  sbrDofId=[];
% 
%                  t=1;
%                  for e=1:length(srdofid)
%                      if find (sinDofId{j,i}==srdofid(e))>0
%                      else
%                      sbrDofId(t)=find(ur2.'==srdofid(e));  %nicht vorbelegen, f�r jede substruktur andere L�nge
%                      t=t+1;
%                      end
%                  end
                 %Einordnung in globales Schema
                 for u=1:length(sbrdofid)
                     help(u)=find(ur2==sbrdofid(u));
                 end
                 gBr(help(1:l),:)=lBr;          
                 %Vz Schema implementieren!! + - + 
                 %                           - + - 
                 
                 if mod(i+j,2)==0
                 Bbr{j,i}=gBr;
                 else
                 Bbr{j,i}=(-1)*gBr;
                 end

                 
               end
           end
          
       end
       
       %define boolean Matrix Bc
       function [Bc,bcg1,bcdofId]=getCornerBooleanMatrix(femModel,sDofArray,bc,gbc,hz,v)
            
            Bc=cell(v,hz);
            bcg = unique(gbc); %globaler Vektor der Eckknoten ids, aufsteigend sortiert, entspricht der Reihenfolge der subdomains
           
            %von Knoten ids auf Knoten:
            bcg1=femModel.getNodes(bcg); 
            
            %von Knoten auf dofs:
            c=1;
            for k=1:length(bcg1)
            bcdof(c:c+1)=bcg1(k).getDofArray;  
            c=c+2;
            end
            %aus globalem bcdof fixed dofs entfernen, auf globale Knoten
            %Ids umstellen
            [~, fixedDofs] = femModel.getDofConstraints;
            if ~ isempty(fixedDofs)
            fixedDofIds = fixedDofs.getId();
            end
            bcdofId= bcdof.getId;
            if ~ isempty(fixedDofIds)
            for c=1:length(fixedDofIds)
            bcdofId(find(bcdofId==fixedDofIds(c)))=[];  %Vektor der globalen bc dofs ohne die fixed dofs
            end
            end
            
            % Bc dofs f�r jede Substruktur berechnen, aus globalen bc und
            % sbc f�r jede Substruktur Bc aufstellen
            for i=1:hz
               for j=1:v
                   sbcdof=Dof.empty;
                   sbc=femModel.getNodes(bc{j,i});
                   c=1;
                   for k=1:length(sbc)
                   sbcdof(c:c+1)=sbc(k).getDofArray;
                   c=c+2;
                   end
                   %falls corner dofs festgehalten: entfernen!
                    [~, fixedDofs] = femModel.getDofConstraints;
                    if ~ isempty(fixedDofs)
                    fixedDofIds = fixedDofs.getId();
                    c=1;
                    sFixedDofId=[]; 
                    for k=1:length(fixedDofIds)
                    if find(sDofArray{j,i}.getId==fixedDofIds(k))>0
                        sFixedDofId(c)=fixedDofIds(k); 
                        c=c+1;
                    end
                    end
                    end
                    sbcdofId=sbcdof.getId;
                    if ~ isempty(sFixedDofId)
                    for c=1:length(sFixedDofId)
                       sbcdofId(find(sbcdofId==sFixedDofId(c)))=[];
                    end
                    end
                   sBc=zeros(length(sbcdofId),length(bcdofId));
                   d=1;
                   for k=1:length(bcdofId)
                   if find(sbcdofId==bcdofId(k))>0
                       sBc(d,k)=1;
                       d=d+1;
                   end
                   end
                   Bc{j,i}=sBc;
               end
           end
       end
       
       %% Assemble all Parameters
       function [FIrr,FIrc,Kcc,Kccg,dr,fcg]=assembleAllParameters(v,hz,sKcc,Krc,Krr,Bc,Br,gfr,gfbc)

           %Matrizen initialisieren
           FIrr=zeros(size(Br{1,1},1));
           FIrc=zeros(size(Br{1,1},1),size(Bc{1,1},2));
           Kcc=zeros(size(Bc{1,1},2),size(Bc{1,1},2));
           Khelp=zeros(size(Kcc));
           dr=zeros(size(Br{1,1},1),1);
           fc=zeros(size(Bc{1,1},2),1);
           fhelp=zeros(size(Bc{1,1},2),1);
           
           for i=1:hz
               for j=1:v  
                   %Lastvektoren in Zeilenvektoren umwandeln:
                   gfr{j,i}=gfr{j,i}.';
                   gfbc{j,i}=gfbc{j,i}.';
                   
                   FIrr=FIrr+Br{j,i}*inv(Krr{j,i})*(Br{j,i}).';
                   FIrc=FIrc+Br{j,i}*inv(Krr{j,i})*Krc{j,i}*Bc{j,i};
                   Kcc=Kcc+Bc{j,i}.'*sKcc{j,i}*Bc{j,i};
                   Khelp=Khelp+(Krc{j,i}*Bc{j,i}).'*inv(Krr{j,i})*Krc{j,i}*Bc{j,i};
                   dr=dr+Br{j,i}*inv(Krr{j,i})*gfr{j,i};
                   fc=fc+Bc{j,i}.'*gfbc{j,i};
                   fhelp=fhelp+Bc{j,i}.'*Krc{j,i}.'*inv(Krr{j,i})*gfr{j,i};  
               end
           end
           Kccg=Kcc-Khelp;
           fcg=fc-fhelp;
       end
       
       
       %% lumped-Preconditioner aufsetzten:
       %Matrix der boundry reminders:
       function[Kbrbr]=getBoundryReminderMatrix(Krr,sinDofId,v,hz)
           %reduzierte Krr Matrix, in zueerst dann br
           Kbrbr=cell(v,hz);
           for i=1:hz
               for j=1:v
                   Krrhelp=Krr{j,i};
                   sinDofIdhelp=sinDofId{j,i};
                   Kbrbr{j,i}=Krrhelp(length(sinDofIdhelp)+1:size(Krrhelp,1),length(sinDofIdhelp)+1:size(Krrhelp,2));
               end
           end
           
       end
       function [lP,A]=getLumpedPreconditioner(Bbr,Kbrbr,sinDofId,srDofId,ur2,v,hz)
           %Matrix W wird als erster versuch als Einheitsmatrix
           %implementiert, als zweiter versuch mit 0.5 auf der
           %hauptdiagonalen
           lP=cell(v,hz);
            for i=1:hz
               for j=1:v
                   Bbrhelp=Bbr{j,i};
                   W=0.5*eye(size(ur2,2));   
                   A=zeros(size(srDofId{j,i},2));
                   A(size(sinDofId{j,i},2)+1:size(A,1),size(sinDofId{j,i},2)+1:size(A,2))=Kbrbr{j,i};
                   slP=W*Bbrhelp*A*Bbrhelp.'*W;
                   lP{j,i}=slP;
               end
            end
              
           
       end
       
       
       function[lPglobal]=assembleLumpedPreconditioner(lP,v,hz)
           lPglobal=zeros(size(lP{1,1}));
            for i=1:hz
               for j=1:v
                   lPglobal=lPglobal+lP{j,i};
               end
            end
       end
       %% Zusatzfunktion: doppelte Knoten (interface nodes) identifizieren
%        
%         function [doubleNodes]= getDoubleNodes(gbr)
%            
%             gsort=sort(gbr);
%             k=1;
%             for i=1:2:length(gsort)
%                 if any(gsort,gsort(i))==1
%                     doubleNodes(k)=gsort(i);
%                     k=k+1;
%                 end
%             end
%         end

 
   end
end