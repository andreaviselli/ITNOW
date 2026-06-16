function [X_u,F_u,Z_u,e_u] = EM_PCA_DFM(X,Z,F_0,q,p,vars,maxiter,dispconv)

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Initialization:

N_m = vars(1);      % Number of monthly variables;
N_q = vars(2);      % Number of quarterly variables;

id_m = logical([ones(N_m,1);zeros(N_q,1)]); % Index of monthly variables;
id_q = logical([zeros(N_m,1);ones(N_q,1)]); % Number of quarterly variables;

% Quarterly restrictions in the measurement (loadings') matrix:

w = [1; 2; 3; 2; 1];                        % Weights on monthly factors;
N_w = length(w);                            % Number of constraints;

Aeq_q = kron([w(2:end),-eye(N_w-1)],eye(q));    % Linear equality constraints;
beq_q = kron(zeros(N_w-1,1),zeros(q,1));        % Constant terms;

% Initialize the starting values:

[T,N] = size(X);
X_u = X;
F = F_0;
e = zeros(T,N);

conv = 0;                       % Logical: 1 if converged;
threshold = 1e-5;               % Stopping threshold;
iter = 0;                       % Iteration number;


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% EM ALGORITHM

while (iter < maxiter) && ~conv

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

    % EXPECTATION STEP
    
    for i = 1:N
        S_i = isnan(X(:,i));
        X_u(S_i,i) = F(S_i,1:N_w*q)*Z(i,1:N_w*q)';
    end

    X_u = normalize(X_u);

    
% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %
    
    % MAXIMIZATION STEP
       
    Z_u = zeros(N,q*N_w);    
    
    % 1. Monthly variables:
    V = cov(X_u);                       % Covariance matrix;
    [W,D] = eigs(V,q,'LM');             % Eigendecomposition;
    W = W*diag(sign(W(1,:))');          % Flip the sign of eigenvectors;
    F_u = X_u*W/sqrt(D);                % Common factors;
    
    Z_m_u = zeros(N_m,1);

    for i = 1:N_m
    
        F_u_m_t = [ones(T,1),F_u];
        b_i = (F_u_m_t'*F_u_m_t)\(F_u_m_t'*X_u(:,i));
        Z_m_u(i,1:q) = b_i(2:end);
    
    end
    
    % Update the monthly loadings:
    Z_u(id_m,1:q) = Z_m_u;
    
    
    % 2. Quarterly variables:
    F_u_q = F(:,1:N_w*q);
    
    for j = id_q
        
        % Unrestricted least squares;
        Z_q_j = (F_u_q'*F_u_q)\(F_u_q'*X_u(:,j));
    
        % Constrained least squares;
        Z_q_j = Z_q_j - ((F_u_q'*F_u_q)\Aeq_q')/ ...
            (Aeq_q/(F_u_q'*F_u_q)*Aeq_q')*(Aeq_q*Z_q_j-beq_q);
    
        % Update the quarterly loadings:    
        Z_u(j,1:N_w*q) = Z_q_j(1:N_w*q)';
        
    end
    
    % Update the idiosyncratic terms:
    e_u = X_u - F_u_q*Z_u';
    
    r = max(p+1,N_w);
    e_u_q = [];
    
    for l = 0:N_w-1
        
        e_u_q = [e_u_q,e_u(r-l:end-l,id_q)];

    end

    e_u_q = [zeros(r-1,N_w*N_q);e_u_q];
    
    % Update the factors:
    F_u = [F_u_q,e_u_q];    
    
    % Add a partition to Z when p > N_w:            
    if p >= N_w
        Z_p = zeros(N,q*(p+1-N_w));
        Z_u = [Z_u,Z_p];
    end
    
    % Add the partition of idiosyncratic terms to Z:
    Z_i = [zeros(N_m,N_w*N_q); kron(eye(N_q),w')];
    Z_u = [Z_u,Z_i];
    

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

    % Check for convergence:
    RMSE_e_u = std(e_u(:)-e(:));

    if RMSE_e_u > threshold
    
        % Set F, Z for the next iteration:
        F = F_u;
        Z = Z_u;
        e = e_u;
        
        % Update the iteration number:
        iter =  iter+1;

    else
        conv = 1;
        
        % Display the output message:
        if dispconv
            if iter < maxiter
                disp(['The EM algorithm has successfully converged at ', ...
                    num2str(iter),' iterations.'])
            elseif iter >= maxiter
                disp(['The EM algorithm stopped because it reached the ' ...
                    'maximum number of iterations.'])
            end
        end
    end
end