function [q,out_param] = integralsim_g(varargin)
%  INTEGRAL_G 1-D guaranteed function integration using trapezoidal rule
% 
%  Description
%
%   q = INTEGRALSIM_G(f) computes q, the definite integral of function f
%   on the interval [0,1] by Simpson's rule with 
%   in a guaranteed absolute error of 1e-6. Default starting number of
%   sample points taken is 100 and default cost budget is 1e7. Input f is a 
%   function handle. The function y = f(x) should accept a vector argument 
%   x and return a vector result y, the integrand evaluated at each element
%   of x.
%
%   q = INTEGRAL_G(f,in_param) computes q, the definite integral of
%   function f by trapezoidal rule within a guaranteed absolute error
%   in_param.abstol, lower bound of initial number of points in_param.nlo,
%   higher bound of initial number of points in_param.nhi, and cost budget
%   in_param.nmax. If a field is not specified, the default value is used.
%   
%   in_param.a --- left end of the integral, default value is 0
%
%   in_param.b --- right end of the integral, default value is 1
%
%   in_param.abstol --- guaranteed absolute error tolerance, default value
%  is 1e-6
% 
%   in_param.nlo --- lowest initial number of function values used, default
%   value is 10
%
%   in_param.nhi --- highest initial number of function values used,
%   default value is 1000
%
%   in_param.nmax --- cost budget (maximum number of function values),
%   default value is 1e7
% 
%   q = INTEGRAL_G(f,a,b,abstol,nlo,nhi,nmax) computes q, the definite
%   integral of function f on the finite interval [a,b] by trapezoidal rule
%   with the ordered input parameters, guaranteed absolute error tolerance
%   abstol, lower bound of initial number of points in_param.nlo, higher
%   bound of initial number of points in_param.nhi, and cost budget nmax.
%
%   q =
%   INTEGRAL_G(f,'a',a,'b',b,'abstol',abstol,'nlo',nlo,'nhi',nhi,,'nmax',nmax)
%   computes q, the definite integral of function f on the finite interval
%   [a,b] by trapezoidal rule within a guaranteed absolute error tolerance
%   abstol, lower bound of initial number of points in_param.nlo, higher
%   bound of initial number of points in_param.nhi, and cost budget nmax.
%   All three field-value pairs are optional and can be supplied.
%
%   [q, out_param] = INTEGRAL_G(f,...) returns the approximated 
%   integration q and output structure out_param, which includes the 
%   fileds in_param plus the following fields:
%
%   out_param.exceedbudget --- it is true if the algorithm tries to use 
%   more points than cost budget, false otherwise.
% 
%   out_param.tauchange --- it is true if the cone constant has been
%   changed, false otherwise. See [1] for details. If true, you may wish to
%   change the input in_param.ninit to a larger number.
% 
%   out_param.npoints --- number of points we need to 
%   reach the guaranteed absolute error tolerance abstol.
%
%   out_param.errest --- approximation error defined as the differences
%   between the true value and the approximated value of the integral.
%
%   out_param.nlo --- lowest initial number of function values
%
%   out_param.nhi --- highest initial number of function values
%
%   out_param.ninit --- initial number of points we use, computed by nlo
%   and nhi
%
%   out_param.nstar --- final value of the parameter defining the cone of
%   functions for which this algorithm is guaranteed; nstar = ninit-2
%   initially and is increased as necessary
%
%   out_param.nmax --- cost budget (maximum number of function values)
%
%   out_param.abstol --- guaranteed absolute error tolerance
% 
%   out_param.a --- low end of the integral
%
%   out_param.b --- high end of the integral
% 
%  Guarantee
%    
%  If the function to be integrated, f, satisfies the cone condition
%                          nstar   ||     f(b)-f(a)  ||
%      ||f''||        <=  -------- ||f'- ----------- ||
%             1           2(b - a) ||       b - a    ||1,
%  then the q output by this algorithm is guaranteed to satisfy
%      ||\int_{a}^{b} f(x) dx - q ||_1 <= abstol,
%  provided the flag exceedbudget = 0. And the upper bound of the cost is
%          ________________________ 
%         /   nstar*(b-a)^2 Var(f') 
%        / ------------------------ + 2 nstar + 4
%      \/          2 abstol
%
%   Examples
%
%   Example 1: 
%   >> q = integralsim_g(@(x) x.^2)
%   q = 0.3333
%
%
%   Example 2:
%   >> f = @(x) exp(-x.^2); q = integralsim_g(f,'a',1,'b',2,'nlo',100,'nhi',10000,'abstol',1e-5,'nmax',1e7)
%   q = 0.1353
%
%
%   Example 3:
%   >> q = integralsim_g()
%   Warning: Function f must be specified. Now GAIL is giving you a toy example of f(x)=x^2.
%   >  In ***
%   q = 0.3333
%
%
%   See also funappx_g, cubMC_g
%
%   Reference:
%   [1]  N. Clancy, Y. Ding, C. Hamilton, F. J. Hickernell, and Y. Zhang, 
%        The complexity of guaranteed automatic algorithms: Cones, not
%        balls, Journal of Complexity 2013, to appear, DOI
%        10.1016/j.jco.2013.09.002.
%
%   [2]  Sou-Cheng T. Choi, Yuhan Ding, Fred J. Hickernell, Lan Jiang,
%        and Yizhi Zhang, "GAIL: Guaranteed Automatic Integration Library
%        (Version 1.3.0)" [MATLAB Software], 2014. Available from
%        http://code.google.com/p/gail/
%
%        If you find GAIL helpful in your work, please support us by citing
%        the above paper and software.
%


% check parameter satisfy conditions or not
[f,out_param] = integralsim_g_param(varargin{:});

%% main alg
out_param.tau=ceil((out_param.ninit-1)*2-1); % computes the minimum requirement of number of points to start
out_param.exceedbudget=false;   % if the number of points used in the calculation of q is less than cost budget
out_param.tauchange=false;  % if the cone constant has been changed
xpts=linspace(0,1,out_param.ninit)'; % generate ninit number of uniformly spaced points in [0,1]
fpts=f(xpts);   % get function values at xpts
sumf=(fpts(1)+fpts(out_param.ninit))/2+sum(fpts(2:out_param.ninit-1));    % computes the sum of trapezoidal rule
ntrap=out_param.ninit-1; % number of trapezoids

while true
    %Compute approximations to the strong and weak norms
    ntrapok=true; %number of trapezoids is large enough for ninit
    df=diff(fpts); %first difference of points
    Gf=sum(abs(df-(fpts(ntrap+1)-fpts(1))/ntrap)); %approx weak norm
    Ff=ntrap*(sum(abs(diff(df)))); %approx strong norm
    
    %Check necessary condition for integrand to lie in cone
    if out_param.tau*(Gf+Ff/(2*ntrap)) < Ff %f lies outside cone
        out_param.tau = 2*Ff/(Gf+Ff/(2*ntrap)); %increase tau
        out_param.tauchange=true; %flag the changed tau
        warning('MATLAB:integral01_g:peaky','This integrand is peaky relative to ninit. You may wish to increase ninit for similar integrands.');
        if ntrap+1 <= (out_param.tau+1)/2 %the present ntrap is too small for tau
            inflation=ceil((out_param.tau+1)/(2*ntrap)); %prepare to increase ntrap
            ntrapok=false; %flag the number of trapezoids too small for tau
        end
    end
    
    if ntrapok %ntrap large enough for tau
        %compute a reliable error estimate
        errest=out_param.tau*Gf/(4*ntrap*(2*ntrap-out_param.tau));
        if errest <= out_param.abstol %tolerance is satisfied
            q=sumf/ntrap; %compute the integral
            break %exit while loop
        else %need to increase number of trapezoids
            %proposed inflation factor to increase ntrap by
            inflation=max(ceil(1/ntrap*sqrt(out_param.tau*Gf/(8*out_param.abstol))),2);
        end
    end
    if ntrap*inflation+1 > out_param.nmax
            %cost budget does not allow intended increase in ntrap
        out_param.exceedbudget=true; %tried to exceed budget
        warning('MATLAB:integral01_g:exceedbudget','integral_g attempts to exceed the cost budget. The answer may be unreliable.');
        inflation=floor((out_param.nmax-1)/ntrap);
            %max possible increase allowed by cost budget
        if inflation == 1 %cannot increase ntrap at all
            q=sumf/ntrap; %compute the integral                 
            break %exit while loop
        end
    end
    
    %Increase number of sample points
    expand=repmat(xpts(1:end-1),1,inflation-1);
    addon=repmat((1:inflation-1)'/(inflation*ntrap),1,ntrap)';
    xnew=expand'+addon'; %additional x values
    ynew=f(xnew); %additional f(x) values
    xnew = [xpts(1:end-1)'; xnew];
    ynew = [fpts(1:end-1)'; ynew];
    xpts = [xnew(:); xpts(end)];
    fpts = [ynew(:); fpts(end)];
    ntrap=ntrap*inflation; %new number of trapezoids
    sumf=(fpts(1)+fpts(ntrap+1))/2+sum(fpts(2:ntrap));
        %updated weighted sum of function values
    if out_param.exceedbudget %tried to exceed cost budget
        q=sumf/ntrap; %compute the integral
        break; %exit while loop
    end
    
end

out_param.q=q;  % integral of functions
out_param.npoints=ntrap+1;  % number of points finally used
out_param.errest=errest;    % error of integral

function [f, out_param] = integralsim_g_param(varargin)
% parse the input to the integral_g function

% Default parameter values
default.abstol  = 1e-6;
default.ninit  = 53; % must be an odd number
default.nmax  = 1e7;


if isempty(varargin)
    help integralsim_g
    warning('Function f must be specified. Now GAIL is giving you a toy example of f(x)=x^2.')
    f = @(x) x.^2;
else
    f = varargin{1};
end;

validvarargin=numel(varargin)>1;
if validvarargin
    in2=varargin{2};
    validvarargin=(isnumeric(in2) || isstruct(in2) ...
        || ischar(in2));
end

if ~validvarargin
    %if only one input f, use all the default parameters
    out_param.abstol = default.abstol;
    out_param.ninit = default.ninit;
    out_param.nmax = default.nmax;
else
    p = inputParser;
    addRequired(p,'f',@isfcn);
    if isnumeric(in2)%if there are multiple inputs with
        %only numeric, they should be put in order.
        addOptional(p,'abstol',default.abstol,@isnumeric);
        addOptional(p,'ninit',default.ninit,@isnumeric);
        addOptional(p,'nmax',default.nmax,@isnumeric);
    else
        if isstruct(in2) %parse input structure
            p.StructExpand = true;
            p.KeepUnmatched = true;
        end
        addParamValue(p,'abstol',default.abstol,@isnumeric);
        addParamValue(p,'ninit',default.ninit,@isnumeric);
        addParamValue(p,'nmax',default.nmax,@isnumeric);
    end
    parse(p,f,varargin{2:end})
    out_param = p.Results;
end;

% let error tolerance greater than 0
if (out_param.abstol <= 0 )
    warning(['Error tolerance should be greater than 0.' ...
            ' Using default error tolerance ' num2str(default.abstol)])
    out_param.abstol = default.abstol;
end
% let ninit be an odd number
if ((out_param.nint+1)/2-ceil(out_param.nint/2) ~= 0 )
    warning(['Initial number of points must be an odd number.' ...
            ' Using default number of points ' num2str(default.ninit)])
    out_param.ninit = default.ninit;
end
% let initial number of points be a positive integer
if (~isposint(out_param.ninit))
    if isposge3(out_param.ninit)
        warning('MATLAB:integral01_g:initnotint',['Initial number of points should be a positive integer.' ...
            ' Using ', num2str(ceil(out_param.ninit))])
        out_param.ninit = ceil(out_param.ninit);
    else
        warning('MATLAB:integral01_g:initlt3',['Initial number of points should be a positive integer.' ...
            ' Using default number of points ' int2str(default.ninit)])
        out_param.ninit = default.ninit;
    end
end
% let cost budget be a positive integer
if (~isposint(out_param.nmax))
    if ispositive(out_param.nmax)
        warning('MATLAB:integral01_g:budgetnotint',['Cost budget should be a positive integer.' ...
            ' Using cost budget ', num2str(ceil(out_param.nmax))])
        out_param.nmax = ceil(out_param.nmax);
    else
        warning('MATLAB:integral01_g:budgetisneg',['Cost budget should be a positive integer.' ...
            ' Using default cost budget ' int2str(default.nmax)])
        out_param.nmax = default.nmax;
    end;
end
