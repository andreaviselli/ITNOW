function inp = InitCond_DFM(X,F_obs,q,p,vars)
% InitCond_DFM()    Initialization of the DFM system matrices.
%
% Description:
%   This function returns the system matrices Z, B, H, Q, F_0,
%   P_0 to be input as the initial conditions for the PCA, 2S 
%   and QMLE estimators.
%    
% Format call: inp = InitCond_DFM(X,F_obs,q,p,vars).


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Initialization

[T,N] = size(X);

N_m = vars(1);
N_q = vars(2);

id_m = logical([ones(N_m,1);zeros(N_q,1)]);
id_q = logical([zeros(N_m,1);ones(N_q,1)]);


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% INITIAL VALUES (FACTORS)
     
X_0 = X;

% Replace missing observations in quarterly 
% variables with cubic splines:

for i = N_m+1:N
    
    t_q = find(~isnan(X(:,i)));
    X_i = rmmissing(X(t_q(1):t_q(end),i));
    X_i = spline(t_q,X_i,t_q(1):t_q(end));
    X_0(t_q(1):t_q(end),i) = X_i;

end

% Replace arbitrary missing observations (yet
% not trailing or leading) with cubic splines:

for i = 1:N_m
    if sum(~isnan(X(:,i))) > 2

        t_m = find(~isnan(X(:,i)));
        X_i = rmmissing(X(t_m(1):t_m(end),i));
        X_i = spline(t_m,X_i,t_m(1):t_m(end));
        X_0(t_m(1):t_m(end),i) = X_i;
        
    end
end

% Imputation of leading or trailing missing
% observations using the fitted values from
% an OLS regression on k_i predictors:

for i = 1:N
    
    X_i = rmmissing(X_0);
    k_i = 5;

    y_i = X_i(:,i);
    X_i(:,i) = [];

    r_i = corr(y_i,X_i);
    r_i_abs = rmmissing(sort(abs(r_i),'descend'));
    r_i_abs = r_i_abs(1:k_i);
    id_r_i = ismember(abs(r_i),r_i_abs);
    
    X_i = X_i(:,id_r_i);
    X_i = [ones(size(X_i,1),1),X_i];
    
    % Suppressing warnings due to collinearity:
    id_warn = 'MATLAB:nearlySingularMatrix';
    warning('off',id_warn)

    b_i = (X_i'*X_i)\(X_i'*y_i);

    warning('on',id_warn)
    
    X_0_i = X_0;
    X_0_i(:,i) = [];
    X_0_i = X_0_i(:,id_r_i);

    id_nan_i = isnan(X_0_i);
    X_0_i(id_nan_i) = 0;
    y_0_i = b_i(1) + X_0_i*b_i(2:end);
    
    id_nan_y_i = isnan(X_0(:,i));
    X_0(id_nan_y_i,i) = y_0_i(id_nan_y_i);

end


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% INITIAL VALUES (SYSTEM MATRICES)

% Quarterly restrictions in the measurement (loadings') matrix:

w = [1; 2; 3; 2; 1];                            % Weights on monthly factors;
N_w = length(w);                                % Number of constraints;

Aeq_q = kron([w(2:end),-eye(N_w-1)],eye(q));    % Linear equality constraints;
beq_q = kron(zeros(N_w-1,1),zeros(q,1));        % Constant terms;

% Adjust the matrix Aeq_q for the presence of
% an arbitrary number of observable factors
% and replace missing observations:

if ~isempty(F_obs)

    N_obs = size(F_obs,2);
    
    for i = 1:N_obs
        t_q = find(~isnan(F_obs(:,i)));
        X_i = rmmissing(F_obs(t_q(1):t_q(end),i));
        X_i = spline(t_q,X_i,t_q(1):t_q(end));
        F_obs(t_q(1):t_q(end),i) = X_i;
    end

    for i = 1:N_obs
        id_nan_i = isnan(F_obs(:,i));
        F_obs(id_nan_i,i) = median(F_obs(~id_nan_i,i),'omitnan');
    end

    % Update linear equality constraints:
    Aeq_q(:,end+1:end+N_obs^2) = zeros(N_w-1,N_obs^2);

else

    N_obs = 0;

end

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Constructing Z (the loadings' matrix):
Z = zeros(N,q*N_w);


% 1. Monthly variables:
N_m_0 = size(X_0,2)-N_q;
X_0_m = X_0(:,1:N_m_0);


% Compute the PCA factor estimates:

V = cov(X_0_m);                 % Indicators' covariance matrix;
[W,D] = eigs(V,q,'LM');         % Eigendecomposition;
W = W*diag(sign(W(1,:))');      % Flip the sign of eigenvectors;
Z_m = W*sqrt(D);                % Factor loadings;
f_0 = X_0_m*W/sqrt(D);          % Common factors;
Z(id_m,1:q) = Z_m;

% Construction of the factors
% (i.e. the state variables):
r = max(p+1,N_w);                                  
F_0 = [];
for l = 0:r-1
    F_0 = [F_0 f_0(r-l:end-l,:)]; 
end


% 2. Quarterly variables:
F_0_L = [F_0(:,1:q*N_w),F_obs(r:end,:)];

id_0_q = size(X_0,2)-N_q+1:size(X_0,2);
Z_obs = [];

for j = id_0_q

    x_q = X_0(r:end,j);
    
    % Unrestricted least squares;
    Z_q_j = (F_0_L'*F_0_L)\(F_0_L'*x_q);

    % Constrained least squares;
    Z_q_j = Z_q_j - ((F_0_L'*F_0_L)\Aeq_q')/ ...
        (Aeq_q/(F_0_L'*F_0_L)*Aeq_q')*(Aeq_q*Z_q_j-beq_q);
    
    Z(j,1:N_w*q) = Z_q_j(1:N_w*q)';
    
    % Add the observable factors if present:
    if ~isempty(F_obs)
        Z_obs = [Z_obs, Z_q_j(N_w*q+N_obs:end)];
    end

end

% Recover the initial number of time periods:
F_0_L = [zeros(r-1,N_w*q); F_0_L(:,1:q*N_w)];

% Turn the observable factor into a parameter in the
% measurement matrix (see Harvey (1990), Chapter 2):

if ~isempty(F_obs)
    F_0_L = [F_0_L, repelem(Z_obs,T,1)];
    Z_obs = [zeros(N-1,N_obs^2); F_obs(1,:)];
end

e_0 = X_0 - F_0_L*[Z,Z_obs]';

% Add a partition to Z when p > N_w:            
if p >= N_w
    Z_p = zeros(N,q*(p+1-N_w));
    Z = [Z Z_p];
end

% Add the partition of idiosyncratic terms to Z:
Z_i = [zeros(N_m,N_w*N_q); kron(eye(N_q),w')];
Z = [Z,Z_i,Z_obs];


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Constructing H (the measurements' error):
H_diag = var(e_0,'omitnan');
H_diag(N_m+1:end) = 1e-04;
H = diag(H_diag);


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Constructing B (the transition matrix):
F_0_0 = F_0(:,1:q);
F_0_1 = F_0(:,q+1:q*(p+1));

r = max(p+1,N_w);
B_1 = zeros(q*r,q*r)';
Phi = (F_0_1'*F_0_1)\(F_0_1'*F_0_0);

B_1(1:q,1:q*p) = Phi';
B_1(q+1:end,1:q*(r-1)) = eye(q*(r-1));

B_2 = kron(eye(N_q),[zeros(1,N_w); eye(N_w-1),zeros(N_w-1,1)]);
B = blkdiag(B_1,B_2);

if ~isempty(F_obs)
    B = blkdiag(B,ones(N_obs^2,1));
end


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Constructing Q (the states' errors):
Q_1 = zeros(r*q,r*q);
u_0 = F_0_0  - F_0_1*Phi;
Q_1(1:q,1:q) = cov(u_0);

Q_2 = blkdiag(1,zeros(N_w-1));
S_e_q = H_diag(N_m+1:N);
Q_2 = kron(diag(S_e_q),Q_2);
Q = blkdiag(Q_1,Q_2);

if ~isempty(F_obs)
    Q = blkdiag(Q,zeros(N_obs^2,1));
end


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Ultimate (re-)construction of the factors:
F_0 = [zeros(r-1,r*q);F_0];

e_0_q = [];

for l = 0:N_w-1
    e_0_q = [e_0_q,e_0(r-l:end-l,id_q)];
end

e_0_q = [zeros(r-1,N_w*N_q);e_0_q];
F_0 = [F_0,e_0_q];


% Swap the observable factors with the corresponding 
% parameters in the measurement matrix to complete 
% the construction of the state variables:

if ~isempty(F_obs)    
    %Z_obs = F_obs;    
    %F_obs = F_0_L(:,q*N_w+1:end);
    %F_0 = [F_0,F_obs];

    FZ_obs = F_0_L(:,q*N_w+1:end);
    F_0 = [F_0,FZ_obs];
end


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Initial value for the estimation error variance
% (including both a stationary and nonstationary
% partition, see Harvey (1990), Chapter 2):

B_lat = B(1:end-N_obs^2,1:end-N_obs^2);
Q_stat = Q(1:end-N_obs^2,1:end-N_obs^2);
m = size(B_lat,1);

vec_P_0 = (eye(m^2)-kron(B_lat,B_lat))\Q_stat(:);
P_0 = reshape(vec_P_0,m,m);

if ~isempty(F_obs)
    P_0 = blkdiag(P_0,10^3*ones(N_obs^2,1));
end


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Input Matrices (output):
inp = struct('X',X,'Z',Z,'F_obs',F_obs,'B',B,'H',H,'Q',Q,'e_0',e_0,'F_0',F_0,'P_0',P_0);