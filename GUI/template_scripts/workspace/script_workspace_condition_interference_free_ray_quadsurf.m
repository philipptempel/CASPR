% Script file for generating the wrench-closure workspace (ray-based)
%
% Author        : Autogenerate
% Created       : 20XX
% Description    :

% Load configs
clear
model_config    =   DevModelConfig('CU-Brick');
cable_set_id    =   'AEI_demo';
% model_config    =   ModelConfig('Example spatial'); 
% cable_set_id    =   'basic_8_cables';
modelObj        =   model_config.getModel(cable_set_id);

q_begin         =   modelObj.bodyModel.q_min; 
q_begin(4:6) = -pi/2;

q_end = modelObj.bodyModel.q_max; 
q_end(4:6) = pi/2;
%% for rotational first
q_begin = [0.5 0.5 0.1 -pi/2 0 0]';
q_end = [0.5 0.5 0.8 pi/2 0 0]';
q_step          =   (modelObj.bodyModel.q_max - modelObj.bodyModel.q_min)/3;
% Set up the workspace simulator
% First the grid
uGrid           =   UniformGrid(q_begin,q_end,q_step,'step_size');
% Workspace settings and conditions

%% this one for a sphere covers some attachment points 
% QuadSurf.implicit_equation = @(x,y,z) x.^2 + y.^2 + z.^2 - 0.2.*x - 1.*y + 0.1.*z + 0.5.*x.*y  + 0.2.*y.*z - 0.3.*x.*z+ 0.04;

%% this one for a sphere that intersected with some cables in translational cases
% QuadSurf.implicit_equation = @(x,y,z) (x-1).^2 + (y+0.5).^2 + (z-0.2).^2 - 0.2.*x - 1.*y + 0.1.*z + 0.4.*x.*y  + 0.2.*y.*z - 0.3.*x.*z+ 0.04;

%% this one for a sphpere that intersected with some cables with a ray in   
% translational and rotational cases
QuadSurf.implicit_equation = @(x,y,z) (x-1)^2+(y-0.5)^2+(z-0.6)^2 -0.2*x-0.5*y+0.2*z+0.4*x*y+0.2*y*z-0.3*x*z+0.2
QuadSurf.boundary = [-2 2 -2 2 0 2.5];
% QuadSurf.implicit_equation = @(x,y,z) x.^2 + y.^2 + (z-0.2).^2 - 0.2.*x - 1.*y + 0.1.*z + 0.4.*x.*y  + 0.2.*y.*z - 0.3.*x.*z+ 0.04;
% 
% @(x,y,z) (x-1)^2+(y-0.5)^2+(z-0.62)^2 -0.2*x-0.5*y+0.2*z+0.4*x*y+0.2*y*z-0.3*x*z+0.2
clf
ob1 = fimplicit3(QuadSurf.implicit_equation,QuadSurf.boundary,'FaceColor',[0.5 0.5 0.5],'EdgeColor','none','FaceAlpha',0.4);
                        hold on;intersected_pts = []; 

hold on
t = linspace(0,1,30)
for i = 1:30
    modelObj.update(q_begin + t(i)*(q_end - q_begin),zeros(modelObj.numDofs,1), zeros(modelObj.numDofs,1),zeros(modelObj.numDofs,1));
    [ee_graph, cable_graph] = draw_robot(modelObj);
%     pause(0.1)
%     if i == 40
    
%     else
        delete(ee_graph);
%     end
%     delete(cable_graph(1));
%     delete(cable_graph(3));
%     delete(cable_graph(4));
%     delete(cable_graph(5));
%     delete(cable_graph(2));
%     delete(cable_graph(7));
%     delete(cable_graph(8));
end

% debug use
% s = sym('s%d',[1 10]);
% QuadSurf.implicit_equation = @(x,y,z) s(1)*x^2 + s(2)*y^2 + s(3)*z^2 + ...
%                                       s(4)*x*y + s(5)*x*z + s(6)*z*y + ...
%                                       s(7)*x + s(8)*y + s(9)*z + s(10);

%% this one for a cylinder covers some attachment points            
% QuadSurf.implicit_equation = @(x,y,z) x.^2 + y.^2 - 0.5;
% QuadSurf.implicit_equation = @(x,y,z) (x - 1).^2 + y.^2 - 0.5;

%% this one for random flat quad surface/cones
% QuadSurf.implicit_equation = @(x,y,z) (0.01.*x+0.5).^2 + (0.02.*y-0.5).^2 - z.^2 -0.4;

QuadSurf.boundary = [-2 2 -2 2 0 2.5];

min_segment_percentage = 1;
w_condition     =   {WorkspaceRayConditionBase.CreateWorkspaceRayCondition(WorkspaceRayConditionType.INTERFERENCE_CABLE_QUADSURF,min_segment_percentage,modelObj,QuadSurf)};

% w_metrics       =   {TensionFactorMetric,ConditionNumberMetric};
% w_metrics       =   {ConditionNumberMetric()};
w_metrics = {};

% Start the simulation
CASPR_log.Info('Start Setup Simulation');
wsim            =    RayWorkspaceSimulator(modelObj,uGrid,w_condition,w_metrics);

% Run the simulation
CASPR_log.Info('Start Running Simulation');
wsim.run()

% %% optional functions (not yet tested)
% 
% % Plot point graph
% wsim.workspace.plotPointGraph(w_condition,w_metrics);
% % Plot ray graph
% wsim.workspace.plotRayGraph(w_condition,w_metrics);
% 
% plot_axis = [1 2 3];
% fixed_variables = wsim.grid.q_begin' + wsim.grid.delta_q' .* [1 3 2 0 0 0];
% % Plot point workspace
% wsim.workspace.plotPointWorkspace(plot_axis,w_condition,fixed_variables)
% 
% % Plot ray workspace
% wsim.workspace.plotRayWorkspace(plot_axis,w_condition,fixed_variables)