function Result = UCM_mode(data,r,ensl)

% data is multiple trial data
% ensl is the enslaving matrix
% r is hypothesical command (e.g., F command [1 1 1 1], M command [di dm dr dl]
% Enslaving is organized in such a way that each row indicate each finger
% task (the 2nd, 3rd, and 4th columns represent the values of non-task
% fingers)


[n,m,l]=size(data);

numTrial = l;

ensl = ensl'; % Transposed enslaving matrix (each row indicates each finger enlsaved force, See Jason's paper)
ENSL = ensl;

averg = mean(data,3);

for m = 1:numTrial;
    data(:,:,m) = data(:,:,m) - averg;
    sub(:,:,m) = data(:,:,m)'; %Transposed data
end


jac = r*ENSL;

for m=1:numTrial
    mode(:,:,m) = inv(ENSL)* sub(:,:,m);
end

evector = (null(jac))';

[nevec,mevec] = size(evector);

DOFUCM = nevec;
DOFORT = length(r) - DOFUCM;


%Projection onto the null space

for m=1:numTrial
    force_parallel(:,:,m) = evector*mode(:,:,m);
    lsq_para(m,:) = sum(force_parallel(:,:,m).^2);
    force_perpendicular(:,:,m)=mode(:,:,m)-evector'*force_parallel(:,:,m);
    lsq_perp(m,:)=sum(force_perpendicular(:,:,m).^2);

end

UCM = mean(lsq_para); %n_ucm=3
UCMorth = mean(lsq_perp); %n_perp=1
Delta =((UCM./DOFUCM)-(UCMorth./DOFORT))./((UCM + UCMorth)./(DOFUCM + DOFORT));

UCM = UCM';
UCMorth = UCMorth';
Delta = Delta';

Result = [UCM./DOFUCM, UCMorth./DOFORT, Delta];