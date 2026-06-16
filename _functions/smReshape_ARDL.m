function sm = smReshape_ARDL(par,id_par,sm)
% smReshape_ARDL()   Auxiliary assemblement of system matrices for 
%                    ARDL models.
%
% Description:
%   This function is an utilty which unpack and reshapes the system 
%   matrices used in autoregressive distributed lag (ARDL) models in 
%   state space form to be estimated by maximum likelihood using the
%   function 'MLE_ARDL.m'.


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

[Z,B,H,Q,beta_0] = deal(sm.Z,sm.B,sm.H,sm.Q,sm.beta);

[N_Z,M_Z] = size(Z);
[N_B,M_B] = size(B);
[N_H,M_H] = size(H);
[N_Q,M_Q] = size(Q);
N_beta = size(beta_0,1);

all_par = [Z(:);B(:);H(:);Q(:);beta_0(:)];
all_par(~id_par) = par;

% -> Z
Znum = N_Z*M_Z;
countL = 1;
countU = Znum;
Zvec = all_par(countL:countU);
Z = reshape(Zvec,N_Z,M_Z);
% -> B
Bnum = N_B*M_B;
countL = countU + 1;
countU = countU + Bnum;
Bvec = all_par(countL:countU);
B = reshape(Bvec,N_B,M_B);
% -> H
Hnum = N_H*M_H;
countL = countU + 1;
countU = countU + Hnum;
Hvec = all_par(countL:countU);
H = reshape(Hvec,N_H,M_H);
% -> Q 
Qnum = N_Q*M_Q;
countL = countU + 1;
countU = countU + Qnum;
Qvec = all_par(countL:countU);
Q = reshape(Qvec,N_Q,M_Q);
% -> beta
countL = countU + 1;
countU = countU + N_beta;
betaVec = all_par(countL:countU);
beta = reshape(betaVec,N_beta,1);

sm = struct('Z',Z,'B',B,'H',H,'Q',Q,'beta',beta);

end