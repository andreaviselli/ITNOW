function [Xu,Fu,Lu] = EM_PCA_MIDAS(X,L0,F0,q,varargin)

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% Initialization:

for n = 1:2:size(varargin,2)
    if strcmp('maxiter',varargin(n))
        maxiter = varargin{n+1};
    elseif strcmp('dispconv',varargin(n))
        dispconv = varargin{n+1};
    end
end
if ~exist('maxiter','var')
    maxiter = 500;
end
if ~exist('dispconv','var')
    dispconv = 1;
end

% Initialize the starting values:

[T,N] = size(X);
Xu = X;
F = F0;
e = zeros(T,N);

conv = 0;                       % Logical: 1 if converged;
threshold = 1e-5;               % Stopping threshold;
iter = 0;                       % Iteration number;


% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

% EM ALGORITHM

while (iter < maxiter) && ~conv

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

    % EXPECTATION STEP
    
    for j = 1:N
        xjId = isnan(X(:,j));
        Xu(xjId,j) = F(xjId,1:q)*L0(j,1:q)';
    end

    Xu = normalize(Xu);

    
% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %
    
    % MAXIMIZATION STEP
    
    V = cov(Xu);                    % Covariance matrix;
    [W,D] = eigs(V,q,'LM');         % Eigendecomposition;
    W = W*diag(sign(W(1,:))');      % Flip the sign of eigenvectors;
    Fu = Xu*W/sqrt(D);              % Common factors;
    
    Lu = zeros(N,q);
    OFu = [ones(T,1),Fu];

    for j = 1:N
        Lambdaj = (OFu'*OFu)\(OFu'*Xu(:,j));
        Lu(j,1:q) = Lambdaj(2:end);    
    end

    eu = Xu - Fu*Lu';
    

% ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ % ~ %

    % Check for convergence:
    RMSE_e_u = std(eu(:)-e(:));

    if RMSE_e_u > threshold
    
        % Set F, L0 for the next iteration:
        F = Fu;
        L0 = Lu;
        e = eu;
        
        % Update the iteration number:
        iter =  iter+1;

    else
        conv = 1;
        
        % Display the output message:
        if dispconv
            if iter < maxiter
                disp(['The EM algorithm has successfully converged at ',num2str(iter),' iterations.'])
            elseif iter >= maxiter
                disp('The EM algorithm stopped because it reached the maximum number of iterations.')
            end
        end
    end
end