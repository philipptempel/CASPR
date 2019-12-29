% Object representation of the wrench-set
%
% Author        : Jonathan EDEN
% Created       : 2015
% Description    :
classdef WrenchSet < handle
        
    properties (SetAccess = protected)
        n_faces = 0                 % The number of faces for the wrench set
        A = []                      % The polytope is described by A*w <= b
        b = []                      % The polytope is described by A*w <= b
        volume = 0                  % The volume of the polytope
        wrenchCombinations = []     % The complete combinations of wrenches
        convexHullIndices = []      % Wrench vertices that represent the convex hull 
    end
    
    methods
        % Build the wrench set given the Jacobian matrix and force
        % bounds. This version calls qhull
%         function id = WrenchSet(L,f_u,f_l,offset)
%             n = size(L,2); m = size(L,1);
%             q = 2^m;
%             f = zeros(q,m);
%             w = zeros(q,n);
%             % Set up the correct directory for logging
%             str = mfilename('fullpath');
%             s_id = strfind(str,'CASPR_private');
%             str  = str(1:s_id+13);
%             str_logs = [str,'data/logs'];
%             if(~exist(str_logs,'dir'))
%                 mkdir(str_logs)
%             end
%             str_io1 = [str_logs,'/wrench_set.txt'];
%             fID = fopen(str_io1,'w');
%             fprintf(fID,'%d\n',n);
%             fprintf(fID,'%d\n',q);
%             for k=1:q
%                 % Convert k to binary
%                 beta = double(dec2bin(k-1,m)) - 48;
%                 f(k,:) = (eye(m) - diag(beta))*f_l + diag(beta)*f_u;
%                 w(k,:) = -L'*f(k,:)';
%                 fprintf(fID,'%5.12f\t',w(k,:));
%                 fprintf(fID,'\n');
%             end
%             fclose(fID);
%             % Now offload to qhull
%             str_io2 = [str_logs,'/convhull.txt'];
%             str_qconvex = ['!',str,'/dependencies/qhull-2012.1/bin/qconvex n Qs < ',str_io1,' > ',str_io2];
%             eval(str_qconvex);
% %             ! ..\..\dependencies\qhull-2012.1\bin\qconvex n Qs < ..\..\logs\wrench_set.txt > ..\..\logs\convhull.txt
%             fID2 = fopen(str_io2);
%             % Read the first two lines of the file
%             n_s = fgets(fID2);
%             n_f = fgets(fID2);
%             T = fscanf(fID2,'%f',[n+1,inf])';
%             fclose(fID2);
%             % Convert to A, b form
%             id.A = T(:,1:n);
%             id.b = -T(:,n+1);
%         end
        
        % Builds the wrench set using the jacobian and force bounds. This
        % version does not make an external system call.
        % The system model is defined as:
        %   w = As * f + offset
        % Note: As is the structure matrix
        function ws = WrenchSet(As, F_u, F_l, offset)
            % n refers to the degree of freedom (dimension of wrench)
            n = size(As,1); 
            % m refers to the number of actuators
            m = size(As,2);
            
            if (nargin < 4 || isempty(offset))
                offset = zeros(n, 1);
            end
            n_points = 2^m;
            F = zeros(n_points, m);
            W = zeros(n_points, n);
            for k=1:n_points
                % Convert k to binary (the double function turns the number
                % to 48 or 49 depending if it is a 0 or 1, respectively
                beta = double(dec2bin(k-1,m)) - 48;
                F(k,:) = (eye(m) - diag(beta))*F_l + diag(beta)*F_u;
                W(k,:) = As*F(k,:)' + offset;
            end
            
            try
                [K, vol] = convhulln(W);
                
                n_faces = size(K,1);
                n_shape = size(K,2);

                t_A = zeros(n_faces, n);
                t_b = zeros(n_faces, 1);
                
                count = 1;
                
                for i = 1:n_faces
                    Wi = W(K(i,2:end),:) - repmat(W(K(i,1),:),n_shape-1,1);
                    Ti = null(Wi)';
                    if(rank(Ti)>1)
                    else
                        t_A(count,:) = Ti;
                        t_b(count,:) = t_A(count,:)*W(K(i,1),:).'; 
                        % Find a new vertex not in the face
                        s_flag = 0; j = 1;
                        while(s_flag == 0)
                            if((sum(j==K(i,:))==0)&&(norm(t_A(count,:)*W(K(j,1),:)'-t_b(count))>1e-6))
                                s_flag = 1;
                            else
                                j = j+1;
                            end
                        end
                        if(t_A(count,:)*W(K(j,1),:)'>t_b(count))
                            t_A(count,:) = -t_A(count,:);
                            t_b(count) = -t_b(count);
                        end
                        count = count + 1;
                    end
                end
                
                ws.A = t_A(1:count-1,:);
                ws.b = t_b(1:count-1);
                ws.n_faces = n_faces;
                ws.volume = vol;
                ws.wrenchCombinations = W;
                ws.convexHullIndices = K;
            catch
            end
            
            
        end
        
        % Approximate the wrench set with a sphere at position G with
        % radius s. The radius corresponds to the radius of the capacity
        % margin
        function w_approx_sphere = sphereApproximationCapacity(obj,G)
            q = obj.n_faces;
            s = zeros(q,1);
            for j=1:q
                s(j) = (obj.b(j) - obj.A(j,:)*G)/norm(obj.A(j,:));
            end
            s = min(s);
            w_approx_sphere = WrenchSetSphere(G,s);
        end
        
        % Determines the largest sphere enclosed within the wrench set.
        function w_approx_sphere = sphereApproximationChebyshev(obj)
            q = obj.n_faces;
            n = size(obj.A,2);
            % Check Chebyshev centre
            A_c = [obj.A,zeros(q,1)];
            for i =1:q
                A_c(i,n+1) = norm(obj.A(i,:));
            end
            C = [0,0,1];
            cvx_begin quiet
                variables o(3)
                maximize( C*o)
                subject to
                A_c*o <= obj.b
            cvx_end
            w_approx_sphere = WrenchSetSphere(o(1:2),o(3));
        end
        
        % Approximate the wrench set with the largest sphere containing the
        % reference point.
        function w_approx_sphere = sphereApproximationMax(obj,x_ref,buffer)
            options = optimoptions('fmincon','Algorithm','active-set','Display','off');
            [T,r,~] = fmincon(@(x) costMinRad(x,obj.A,obj.b),[0;0],obj.A,obj.b,[],[],[],[],@(x) constraintPointContained(x,obj.A,obj.b,x_ref,buffer),options);
            w_approx_sphere = WrenchSetSphere(T,r);
        end
        
        % Approximates the wrench set to account for the coriolis.
        function w_approx_sphere = sphereApproximationCoriolis(obj,G,q2)
            % THIS NEEDS TO BE CHANGED LATER
            q = obj.n_faces;
            s = zeros(q,1);
            t = sign(sin(q2));
            for j=1:q
                s(j) = (obj.b(j) - obj.A(j,:)*G)/norm(obj.A(j,:));
                p = dynamics.G + s(j)*(w.A(j,:)')/norm(w.A(j,:));
                if(t*(p(2)-dynamics.G(2))<0)
                    pd = (1/w.A(j,1))*(w.b(j) - w.A(j,2)*dynamics.G(2));
                    if(abs(pd)==Inf)
                        s(j) = Inf;
                    else
                        s(j) = abs(pd - dynamics.G(1));
                    end
                    % Find the correct intersection of the boundary ray to the line
                end
            end
            s = min(s);
            w_approx_sphere = WrenchSetSphere(G,s);
        end
    end
end

