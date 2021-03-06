
#' Build data input for VAST model
#'
#' \code{Data_Fn} builds a tagged list of data inputs used by TMB for running the model
#'
#' @param Version a version number (see example for current default).
#' @param FieldConfig a vector of format c("Omega1"=0, "Epsilon1"=10, "Omega2"="AR1", "Epsilon2"=10), where Omega refers to spatial variation, Epsilon refers to spatio-temporal variation, Omega1 refers to variation in encounter probability, and Omega2 refers to variation in positive catch rates, where 0 is off, "AR1" is an AR1 process, and >0 is the number of elements in a factor-analysis covariance
#' @param OverdispersionConfig OPTIONAL, a vector of format c("eta1"=0, "eta2"="AR1") governing any correlated overdispersion among categories for each level of v_i, where eta1 is for encounter probability, and eta2 is for positive catch rates, where 0 is off, "AR1" is an AR1 process, and >0 is the number of elements in a factor-analysis covariance
#' @param ObsModel an optimal vector of format c("PosDist"=1,"Link"=0), where PosDist specifies the distribution for positive catch rates (0 is normal, 1 is lognormal, 2 is gamma), and Link is the functional form for encounter probabilities (0 is conventional logit-link, 1 is a novel parameterization involving density)
#' @param b_i Sampled biomass for each observation i
#' @param a_i Sampled area for each observation i
#' @param c_i Category (e.g., species, length-bin) for each observation i
#' @param s_i Spatial knot (e.g., grid cell) for each observation i
#' @param t_i Time interval (e.g., year) for each observation i
#' @param a_xl Area associated with each knot
#' @param MeshList, tagged list representing location information for the SPDE mesh hyperdistribution
#' @param GridList, tagged list representing location information for the 2D AR1 grid hyperdistribution
#' @param Method, character (either "Mesh" or "Grid") specifying hyperdistribution (Default="Mesh")
#' @param v_i OPTIONAL, sampling category (e.g., vessel or tow) associated with overdispersed variation for each observation i
#' @param PredTF_i OPTIONAL, whether each observation i is included in the likelihood (PredTF_i[i]=0) or in the predictive probability (PredTF_i[i]=1)
#' @param X_xj OPTIONAL, matrix of static density covariates (e.g., measured variables affecting density, as used when interpolating density for calculating an index of abundance)
#' @param X_xtp OPTIONAL, array of dynamic (varying among time intervals) density covariates
#' @param Q_ik OPTIONAL, matrix of catchability covariates (e.g., measured variables affecting catch rates but not caused by variation in species density) for each observation i
#' @param Aniso OPTIONAL, whether to assume isotropy (Aniso=0) or geometric anisotropy (Aniso=1)
#' @param RhoConfig OPTIONAL, vector of form c("Beta1"=0,"Beta2"=0,"Epsilon1"=0,"Epsilon2"=0) specifying whether either intercepts (Beta1 and Beta2) or spatio-temporal variation (Epsilon1 and Epsilon2) is structured among time intervals
#' @param Options OPTIONAL, a vector of form c('SD_site_density'=0,'SD_site_logdensity'=0,'Calculate_Range'=0,'Calculate_evenness'=0,'Calculate_effective_area'=0,'Calculate_Cov_SE'=0), where Calculate_Range=1 turns on calculation of center of gravity, and Calculate_effective_area=1 turns on calculation of effective area occupied
#' @param CheckForErrors OPTIONAL, whether to check for errors in input (NOTE: when CheckForErrors=TRUE, the function will throw an error if it detects a problem with inputs.  However, failing to throw an error is no guaruntee that the inputs are all correct)

#' @return Tagged list containing inputs to function Build_TMB_Fn()

#' @export
Data_Fn <-
function( Version, FieldConfig, OverdispersionConfig=c("eta1"=0,"eta2"=0), ObsModel=c("PosDist"=1,"Link"=0), b_i, a_i, c_i, s_i, t_i, a_xl, MeshList, GridList, Method, v_i=rep(0,length(b_i)), PredTF_i=rep(0,length(b_i)), X_xj=NULL, X_xtp=NULL, Q_ik=NULL, Aniso=1, RhoConfig=c("Beta1"=0,"Beta2"=0,"Epsilon1"=0,"Epsilon2"=0), Options=c('SD_site_density'=0,'SD_site_logdensity'=0,'Calculate_Range'=0,'Calculate_evenness'=0,'Calculate_effective_area'=0,'Calculate_Cov_SE'=0), CheckForErrors=TRUE ){

  # Determine dimensions
  n_t = max(t_i) - min(t_i) + 1
  n_c = max(c_i) + 1
  n_v = length(unique(v_i))   # If n_v=1, then turn off overdispersion later
  n_i = length(b_i)
  n_x = nrow(a_xl)
  n_l = ncol(a_xl)

  # Covariates and defaults
  if( is.null(X_xj) ) X_xj = matrix(0, nrow=n_x, ncol=1)
  if( is.null(X_xtp) ) X_xtp = array(0, dim=c(n_x,n_t,1))
  if( is.null(Q_ik) ) Q_ik = matrix(0, nrow=n_i, ncol=1)
  n_j = ncol(X_xj)
  n_p = dim(X_xtp)[3]
  n_k = ncol(Q_ik)

  # Translate FieldConfig from input formatting to CPP formatting
  FieldConfig_input = rep(NA, length(FieldConfig))
  names(FieldConfig_input) = names(FieldConfig)
  g = function(vec) suppressWarnings(as.numeric(vec))
  FieldConfig_input[] = ifelse( FieldConfig=="AR1", 0, FieldConfig_input)
  FieldConfig_input[] = ifelse( !is.na(g(FieldConfig)) & g(FieldConfig)>0 & g(FieldConfig)<=n_c, g(FieldConfig), FieldConfig_input)
  FieldConfig_input[] = ifelse( !is.na(g(FieldConfig)) & g(FieldConfig)==0, -1, FieldConfig_input)
  if( any(is.na(FieldConfig_input)) ) stop( "'FieldConfig' must be: 0 (turn off overdispersion); 'AR1' (use AR1 structure); or 0<n_f<=n_c (factor structure)" )
  message( "FieldConfig_input is:" )
  print(FieldConfig_input)

  # Translate OverdispersionConfig from input formatting to CPP formatting
  OverdispersionConfig_input = rep(NA, length(OverdispersionConfig))
  names(OverdispersionConfig_input) = names(OverdispersionConfig)
  g = function(vec) suppressWarnings(as.numeric(vec))
  OverdispersionConfig_input[] = ifelse( OverdispersionConfig=="AR1", 0, OverdispersionConfig_input)
  OverdispersionConfig_input[] = ifelse( !is.na(g(OverdispersionConfig)) & g(OverdispersionConfig)>0 & g(OverdispersionConfig)<=n_c, g(OverdispersionConfig), OverdispersionConfig_input)
  OverdispersionConfig_input[] = ifelse( !is.na(g(OverdispersionConfig)) & g(OverdispersionConfig)==0, -1, OverdispersionConfig_input)
  if( all(OverdispersionConfig_input<0) ){
    v_i = rep(0,length(b_i))
    n_v = 1
  }
  if( any(is.na(OverdispersionConfig_input)) ) stop( "'OverdispersionConfig' must be: 0 (turn off overdispersion); 'AR1' (use AR1 structure); or 0<n_f<=n_c (factor structure)" )
  message( "OverdispersionConfig_input is:" )
  print(OverdispersionConfig_input)

  # by default, add nothing as Z_xl
  if( Options['Calculate_Range']==FALSE ){
    Z_xm = matrix(0, nrow=nrow(a_xl), ncol=ncol(a_xl) ) # Size so that it works for Version 3g-3j
  }
  if(Options['Calculate_Range']==TRUE ){
    Z_xm = MeshList$loc_x
    message( "Calculating range shift for stratum #1:",colnames(a_xl[1]))
  }

  # Check for bad data entry
  if( CheckForErrors==TRUE ){
    if( !is.matrix(a_xl) | !is.matrix(X_xj) | !is.matrix(Q_ik) ) stop("a_xl, X_xj, and Q_ik should be matrices")
    if( (max(s_i)-1)>n_x | min(s_i)<0 ) stop("s_i exceeds bounds in MeshList")
    if( any(a_i<=0) ) stop("a_i must be greater than zero for all observations, and at least one value of a_i is not")
  }

  # Check for bad data entry
  if( CheckForErrors==TRUE ){
    if( any(c(length(b_i),length(a_i),length(c_i),length(s_i),length(t_i),length(v_i))!=n_i) ) stop("b_i, a_i, c_i, s_i, v_i, or t_i doesn't have length n_i")
    if( nrow(a_xl)!=n_x | ncol(a_xl)!=n_l ) stop("a_xl has wrong dimensions")
    if( nrow(X_xj)!=n_x | ncol(X_xj)!=n_j ) stop("X_xj has wrong dimensions")
    if( nrow(Q_ik)!=n_i | ncol(Q_ik)!=n_k ) stop("Q_ik has wrong dimensions")
  }

  # switch defaults if necessary
  if( Method=="Grid" ){
    Aniso = 0
    message("Using isotropic 2D AR1 hyperdistribution, so switching to Aniso=0")
  }

  # Output tagged list
  Options_vec = c("Aniso"=Aniso, "R2_interpretation"=0, "Rho_betaTF"=ifelse(RhoConfig[["Beta1"]]|RhoConfig[["Beta2"]],1,0), "Alpha"=0, "AreaAbundanceCurveTF"=0, "CMP_xmax"=30, "CMP_breakpoint"=10, "Method"=switch(Method,"Mesh"=0,"Grid"=1) )
  if(Version%in%c("VAST_v1_1_0","VAST_v1_0_0")){
    Return = list( "n_i"=n_i, "n_s"=c(MeshList$spde$n.spde,n_x)[Options_vec['Method']+1], "n_x"=n_x, "n_t"=n_t, "n_c"=n_c, "n_j"=n_j, "n_p"=n_p, "n_k"=n_k, "n_l"=n_l, "n_m"=ncol(Z_xm), "Options_vec"=Options_vec, "FieldConfig"=FieldConfig_input, "ObsModel"=ObsModel, "Options"=Options, "b_i"=b_i, "a_i"=a_i, "c_i"=c_i, "s_i"=s_i, "t_i"=t_i-min(t_i), "a_xl"=a_xl, "X_xj"=X_xj, "X_xtp"=X_xtp, "Q_ik"=Q_ik, "Z_xm"=Z_xm, "spde"=list(), "spde_aniso"=list() )
  }
  if(Version%in%c("VAST_v1_4_0","VAST_v1_3_0","VAST_v1_2_0")){
    Return = list( "n_i"=n_i, "n_s"=c(MeshList$spde$n.spde,n_x)[Options_vec['Method']+1], "n_x"=n_x, "n_t"=n_t, "n_c"=n_c, "n_j"=n_j, "n_p"=n_p, "n_k"=n_k, "n_v"=n_v, "n_f_input"=OverdispersionConfig_input[1], "n_l"=n_l, "n_m"=ncol(Z_xm), "Options_vec"=Options_vec, "FieldConfig"=FieldConfig_input, "ObsModel"=ObsModel, "Options"=Options, "b_i"=b_i, "a_i"=a_i, "c_i"=c_i, "s_i"=s_i, "t_i"=t_i-min(t_i), "v_i"=match(v_i,sort(unique(v_i)))-1, "a_xl"=a_xl, "X_xj"=X_xj, "X_xtp"=X_xtp, "Q_ik"=Q_ik, "Z_xm"=Z_xm, "spde"=list(), "spde_aniso"=list() )
  }
  if(Version%in%c("VAST_v1_6_0","VAST_v1_5_0")){
    Return = list( "n_i"=n_i, "n_s"=c(MeshList$spde$n.spde,n_x)[Options_vec['Method']+1], "n_x"=n_x, "n_t"=n_t, "n_c"=n_c, "n_j"=n_j, "n_p"=n_p, "n_k"=n_k, "n_v"=n_v, "n_f_input"=OverdispersionConfig_input[1], "n_l"=n_l, "n_m"=ncol(Z_xm), "Options_vec"=Options_vec, "FieldConfig"=FieldConfig_input, "ObsModel"=ObsModel, "Options"=Options, "b_i"=b_i, "a_i"=a_i, "c_i"=c_i, "s_i"=s_i, "t_i"=t_i-min(t_i), "v_i"=match(v_i,sort(unique(v_i)))-1, "PredTF_i"=PredTF_i, "a_xl"=a_xl, "X_xj"=X_xj, "X_xtp"=X_xtp, "Q_ik"=Q_ik, "Z_xm"=Z_xm, "spde"=list(), "spde_aniso"=list() )
  }
  if(Version%in%c("VAST_v1_7_0")){
    Return = list( "n_i"=n_i, "n_s"=c(MeshList$spde$n.spde,n_x)[Options_vec['Method']+1], "n_x"=n_x, "n_t"=n_t, "n_c"=n_c, "n_j"=n_j, "n_p"=n_p, "n_k"=n_k, "n_v"=n_v, "n_l"=n_l, "n_m"=ncol(Z_xm), "Options_vec"=Options_vec, "FieldConfig"=FieldConfig_input, "OverdispersionConfig"=OverdispersionConfig_input, "ObsModel"=ObsModel, "Options"=Options, "b_i"=b_i, "a_i"=a_i, "c_i"=c_i, "s_i"=s_i, "t_i"=t_i-min(t_i), "v_i"=match(v_i,sort(unique(v_i)))-1, "PredTF_i"=PredTF_i, "a_xl"=a_xl, "X_xj"=X_xj, "X_xtp"=X_xtp, "Q_ik"=Q_ik, "Z_xm"=Z_xm, "spde"=list(), "spde_aniso"=list() )
  }
  if(Version%in%c("VAST_v1_8_0")){
    Return = list( "n_i"=n_i, "n_s"=c(MeshList$spde$n.spde,n_x)[Options_vec['Method']+1], "n_x"=n_x, "n_t"=n_t, "n_c"=n_c, "n_j"=n_j, "n_p"=n_p, "n_k"=n_k, "n_v"=n_v, "n_l"=n_l, "n_m"=ncol(Z_xm), "Options_vec"=Options_vec, "FieldConfig"=FieldConfig_input, "OverdispersionConfig"=OverdispersionConfig_input, "ObsModel"=ObsModel, "Options"=Options, "b_i"=b_i, "a_i"=a_i, "c_i"=c_i, "s_i"=s_i, "t_i"=t_i-min(t_i), "v_i"=match(v_i,sort(unique(v_i)))-1, "PredTF_i"=PredTF_i, "a_xl"=a_xl, "X_xj"=X_xj, "X_xtp"=X_xtp, "Q_ik"=Q_ik, "Z_xm"=Z_xm, "spde"=list(), "spde_aniso"=list(), "M0"=GridList$M0, "M1"=GridList$M1, "M2"=GridList$M2 )
  }
  if( "spde" %in% names(Return) ) Return[['spde']] = INLA::inla.spde2.matern(MeshList$mesh)$param.inla[c("M0","M1","M2")]
  if( "spde_aniso" %in% names(Return) ) Return[['spde_aniso']] = list("n_s"=MeshList$spde$n.spde, "n_tri"=nrow(MeshList$mesh$graph$tv), "Tri_Area"=MeshList$Tri_Area, "E0"=MeshList$E0, "E1"=MeshList$E1, "E2"=MeshList$E2, "TV"=MeshList$TV-1, "G0"=MeshList$spde$param.inla$M0, "G0_inv"=INLA::inla.as.dgTMatrix(solve(MeshList$spde$param.inla$M0)) )

  # Check for NAs
  if( CheckForErrors==TRUE ){
    if( any(sapply(Return, FUN=function(Array){any(is.na(Array))})==TRUE) ) stop("Please find and eliminate the NA from your inputs") 
  }

  # Return
  return( Return )
}
