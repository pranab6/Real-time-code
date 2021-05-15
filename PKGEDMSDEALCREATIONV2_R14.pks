CREATE OR REPLACE PACKAGE         PKGEDMSDEALCREATIONV2_EDP
is
--  PRAGMA SERIALLY_REUSABLE;
TYPE t_rollout_mnths IS VARRAY (25) OF VARCHAR2 (1000);

TYPE array_pl IS TABLE OF VARCHAR2 (50);

TYPE rctype IS REF CURSOR;
SUBTYPE decimal_type IS DECIMAL(12,2);
SUBTYPE gypsy_rec  is  gt_product_bundles_prices%rowtype;

--global constants

  con_deal_source_bmi              CONSTANT VARCHAR2(20)  :='BMI';
  con_type_warning              CONSTANT VARCHAR2(10)  :='WARNING';
  con_type_error                CONSTANT VARCHAR2(10)  :='ERROR';
  con_type_success              CONSTANT VARCHAR2(10)  :='SUCCESS';
  con_type_info                 CONSTANT VARCHAR2(10)  :='INFO';
  con_err_zero_version_deal       CONSTANT VARCHAR2(100) := 'Product not found in Gypsy. Cannot proceed. Only zero (0) version deal will be created' ;
  con_gypsy_high_price_mismatch CONSTANT VARCHAR2(100) := 'Gypsy price is greater than BMI price for the product : ';--'Gypsy price is greater than smart quote price for the product : ';
  con_gypsy_low_price_mismatch  CONSTANT VARCHAR2(100) := 'Gypsy price is lesser than BMI price for the product : ' ;--'Gypsy price is lesser than smart quote price for the product : ' ;
  con_CUST_IND_EMPTY            CONSTANT VARCHAR2(100) :='Customer Industry is mandatory for the deal and cannot be empty';
  con_cust_ind_invalid          CONSTANT VARCHAR2(100) :='Customer Industry does not exists in Eclipse ';
  con_deal_user_type_cd_oe        CONSTANT VARCHAR2(2)   :='OE';
  con_HIGH_TOUCH_DEALTYPE_DESC    CONSTANT VARCHAR2(15)  :='HIGH_TOUCH';
  con_LOW_TOUCH_DEALTYPE_DESC     CONSTANT VARCHAR2(15)  :='LOW_TOUCH';
  con_ht_reroute_dealtype_desc   CONSTANT VARCHAR2(21)  :='HIGH_TOUCH_REROUTED';
  con_request_type_add            CONSTANT VARCHAR2(3)   :='ADD';
  con_request_type_add_copy_src   CONSTANT VARCHAR2(20)  :='ADD_COPY_SOURCE';---change New xml
  con_request_type_update         CONSTANT VARCHAR2 (6)  :='UPDATE';
  --Bundle type constants
  con_bundle_source_watson   CONSTANT VARCHAR2(10):='WATSON';
  con_bundle_source_ngce     CONSTANT VARCHAR2(10):='NGCE';    --Added for ePrime and BMI
  con_bundle_source_ngce_fix CONSTANT VARCHAR2(10):='NGCE-FIX';--Added for ePrime and BMI
  con_bundle_source_ezconfig CONSTANT VARCHAR2(10):='EZCONFIG';--added for ePrime requirement
  con_bundle_source_ecfix    CONSTANT VARCHAR2(10):='EC-FIX';
  con_bundle_source_ecband   CONSTANT VARCHAR2(10):='EC-BAND';
  con_bundle_source_soft     CONSTANT VARCHAR2(10):='SOFT';

  FUNCTION GetSQTXMLValue(
      i_xpathExpression IN VARCHAR2,
      i_guid            IN VARCHAR2)
    RETURN VARCHAR2;
  PROCEDURE InsertError_OutPut_Messages(
      i_bd_id IN NUMBER,
      i_bd_nr            NUMBER,
      i_bd_version_nr    NUMBER,
      i_deal_prog_cd     VARCHAR2,
      i_bdme_aprvl_cd    VARCHAR2,
      i_quote_dist_cd    VARCHAR2,
      i_euv_stat_cd      VARCHAR2,
      i_high_risk_fl     VARCHAR2,
      i_risk_reason_desc VARCHAR2,
      i_risk_desc        VARCHAR2,
      i_error_desc       VARCHAR2,
      i_msg_type         VARCHAR2,
      i_deal_guid        VARCHAR2,
      i_WON_LOST_STAT_CD VARCHAR2,
      i_quote_dist_dt_gmt DATE,
      i_user_message varchar2);
  PROCEDURE UpdateDealEUV(
      i_bd_id NUMBER,
      i_send_quote_fl IN VARCHAR2,
      i_gen_opg_fl IN VARCHAR2,
      p_EUVResult OUT SYS_REFCURSOR);
  PROCEDURE GetDealStatus(
      i_bd_id NUMBER,
      p_DealStatus OUT SYS_REFCURSOR);
  PROCEDURE UpdateWonLost(
      i_bd_id           NUMBER,
      i_won_lost_code   VARCHAR2,
      i_won_lost_emp_email VARCHAR2,
    --  i_won_lost_emp_nr NUMBER,
      i_gen_opg_fl varchar2,
      i_won_lost_prob_pct IN NUMBER, --New parameter added by Lakshmi to update Won/Loss probability
      p_wonlost_results OUT SYS_REFCURSOR);
  FUNCTION PerformRiskAssesment(
      i_euv_required_fl VARCHAR2,
      i_euv_comp_fl     VARCHAR2,
      i_euv_at_won_fl   VARCHAR2,
      i_deal_risk_fl    VARCHAR2,
      i_bd_nr           NUMBER,
      i_bd_version_nr   NUMBER,
      i_bd_id           NUMBER,
      i_quoted_status   VARCHAR2,
      i_wl_stat_cd      VARCHAR2)
    RETURN VARCHAR2;
  PROCEDURE RouteDeal(
      i_bd_id   NUMBER,
      i_user_id VARCHAR2,
      p_route_deal_result OUT SYS_REFCURSOR);
  PROCEDURE insert_prod_line(
      i_bd_id                   NUMBER,
      i_bd_nr                   NUMBER,
      i_bd_version_nr           NUMBER,
      i_line_prog_cd            VARCHAR2,
      i_deal_prog_cd            VARCHAR2,
      i_bdme_aprvl_cd           VARCHAR2,
      i_quote_dist_cd           VARCHAR2,
      i_euv_stat_code           VARCHAR2,
      i_high_risk_fl            VARCHAR2,
      i_risk_reasion_desc       VARCHAR2,
      i_risk_desc               VARCHAR2,
      i_deal_creation_guid      VARCHAR2,
      i_countrycd               VARCHAR2,
      i_pricelistcd             VARCHAR2,
      i_currencycd              VARCHAR2,
      i_pricetermcd             VARCHAR2,
      i_prod_string             VARCHAR2,
      i_globai_fl               VARCHAR2,
      i_hierarchy_cd            VARCHAR2,
      i_enddate                 VARCHAR2,
      i_line_type_cd            VARCHAR2,
      i_prod_list_price         NUMBER,
      i_prod_auth_basis_text    VARCHAR2,
      i_prod_qty                NUMBER,
      i_bdnetamt                NUMBER,
      i_auth_emp_nr             NUMBER,
      i_auth_mc_hp_emp_nr       NUMBER,
      i_line_added_by_emp_nr    NUMBER,
      i_pricingtypecd           VARCHAR2,
      i_line_nr                 NUMBER,
      i_begindate               VARCHAR2,
      i_add_bundles             VARCHAR2,
      i_add_bundleHeader        VARCHAR2,
      i_config_src              VARCHAR2,
      i_config_id              VARCHAR2,-- NUMBER,  commented as part of Cr5020
      i_source_config_id        VARCHAR2,
      i_stddiscpct              number,
      i_line_item_nr_for_bundle number,
      i_auth_stat_cd varchar2,
      i_opt_cd  varchar2,
      I_ROLLOUTMONTHQTYS varchar2,
      --I_AUTHDATEGMT varchar2,
     -- i_auth_mc_date varchar2,
      I_AUTHDATEGMT DATE, --Changed as per CR:236715
      i_auth_mc_date DATE, --Changed as per CR:236715
      i_dealsourcedealtype varchar2,
      i_bd_line_qty_for_hdr_sku number      ,
      i_bundle_desc varchar2,
      I_SKU_PL                      varchar2,   ---Added for CR3236
      I_BD_HDR_LINE_AUTH_BD_NET LINE_DISC_SCALE.RQST_BD_NET_PRC_AM%type,
      i_prod_cost_price number,
      i_prod_cost_price_hdr_prod number,
      i_busmodelcd varchar2,  ---Added  for CR 4774
      i_minorder_qty VARCHAR2 ,---Added for CR 4735
      i_line_auth_type line_item.line_auth_type%type,--added for new auth changes
      i_line_authdesc  VARCHAR2,
      i_line_AuthStat  bundle_line.ITEM_PROG_CD%type,
      i_line_AuthDtGMT DATE,
      o_create_new_version out varchar,
      I_BANDED_FL varchar2,
      i_bmi_doc_no varchar2,
      i_prod_desc  LINE_ITEM.PROD_GNRC_DESC_TX%TYPE,  --Added by Ramesh on 17-Feb-2014 for proddesc for R8,
      I_EXT_PRE_APPRV_PRC_AM LINE_DISC_SCALE.EXT_PRE_APPRV_PRC_AM%TYPE,
      i_total_hdr_listprice_value NUMBER,
      i_total_hdr_bdnet_value number,
      i_DisplayCompPrcFl VARCHAR2,
      i_guidance_available_fl VARCHAR2,
      i_guidance_details_id NUMBER,
      i_guidance_expert_pct NUMBER,
      i_guidance_floor_pct NUMBER,
      i_guidance_typical_pct NUMBER,
      i_guidance_last_refresh_dt VARCHAR2,
      i_non_discount_fl VARCHAR2
     ,i_InstantPrcMethod  bundle_line.INSTANT_PRC_METHOD%TYPE  --Added for UsS7301
    ,i_InstantPrcAmount  bundle_line.INSTANT_PRC_AMT%TYPE --Added for US 7301
    ,i_ContraAMt bundle_line_contra.CONTRA_AMT%TYPE ---Added for US 7301
    , i_use_ext_list_price    GT_XML_line_item.use_ext_list_price%TYPE --New variable added by Lakshmi for HP SW Project
);
  FUNCTION Convert_to_US_CURRENCY(
      i_curr_cd          VARCHAR2,
      i_pl_cd            VARCHAR2,
      i_deal_est_value   NUMBER,
      i_exchange_rate_cd VARCHAR2,
      i_tenantid VARCHAR2) --Added for SMO changes
    RETURN NUMBER;
  PROCEDURE GetEconomicRows(
      i_bus_unit_cd             VARCHAR2,
      i_region_cd               VARCHAR2,
      i_country_cd              VARCHAR2,
      i_model_grp_cd            VARCHAR2,
      i_get_std_disc_fl         VARCHAR2,
      i_lead_bus_grp            VARCHAR2,
      i_deal_est_value          NUMBER,
      i_est_deal_value_disc_pct NUMBER,
      i_first_tier_row          VARCHAR2,
      p_ecoresults OUT SYS_REFCURSOR);
  PROCEDURE get_economic_data(
      i_region_cd               VARCHAR2,
      i_country_cd              VARCHAR2,
      i_model_grp_cd            VARCHAR2,
      i_get_std_disc_fl         VARCHAR2,
      i_lead_bus_grp            VARCHAR2,
      i_bus_unit_cd             VARCHAR2,
      i_first_tier_row          VARCHAR2,
      i_deal_est_value          NUMBER,
      i_est_deal_value_disc_pct NUMBER,
      p_ecoresults OUT SYS_REFCURSOR);
  PROCEDURE Calculate_Deal_Risk(
      i_bd_id NUMBER,
      i_risk_reason OUT VARCHAR2,
      i_error_message OUT VARCHAR2);
  PROCEDURE get_rollout_months(
      p_str IN VARCHAR2,
      p_array OUT t_rollout_mnths);
  FUNCTION get_quote_recepients_list(
      i_bd_id IN NUMBER )
    RETURN VARCHAR2;
  FUNCTION ADD_RESELLER_A(
      i_deal_creation_guid IN VARCHAR2,
      i_xmlnamespace      VARCHAR2,
      i_bd_id             NUMERIC,
      i_country_cd        VARCHAR2,
      i_region_cd         VARCHAR2,
      i_bus_model_cd      VARCHAR2,
      i_rslr_added_emp_nr NUMERIC ,
      o_error_message out varchar2)
    RETURN VARCHAR2;
  PROCEDURE GET_BD_HDR_AUTH_LIST_AMT(
      i_xml_path_to_Query IN VARCHAR2,
      i_deal_creation_guid IN VARCHAR2,
      i_xmlnamespace        VARCHAR2,
      i_bundle_parent_index NUMERIC,
      i_bundle_source       VARCHAR2,
      i_hdr_sku             VARCHAR2,
      O_LIST_PRICE OUT numeric,
      O_AUTH_BDNET_AMT OUT LINE_DISC_SCALE.RQST_BD_NET_PRC_AM%type,
      O_HDR_SKU_QTY OUT numeric,
      O_HDR_SKU_OPT_CD OUT varchar2,
      O_PROD_COST_PRICE_HDR_PROD OUT numeric,
      O_HDR_PROD_STD_DISC OUT numeric,
      O_line_AuthBasisDesc  OUT VARCHAR2,
      O_line_authstat OUT bundle_line.ITEM_PROG_CD%type,
      O_line_AuthDtGMT OUT DATE
      );
  FUNCTION ADD_RESELLER_B(
      i_deal_creation_guid IN VARCHAR2,
      i_xmlnamespace      VARCHAR2,
      i_bd_id             NUMERIC,
      i_country_cd        varchar2,
      i_region_cd         VARCHAR2,
      i_bus_model_cd      VARCHAR2,
      i_rslr_added_emp_nr NUMERIC ,
      o_error_message out varchar2)
    return varchar2;
procedure  ins_eu_auth_affil(
    i_bd_id IN NUMBER,
    i_deal_creation_guid in varchar2,
    i_xmlnamespace      varchar2   );
function update_deal_status_values (i_bd_id numeric)  return numeric;
PROCEDURE  ins_deal_comment_memo(i_bd_id IN NUMBER,
    i_deal_creation_guid IN VARCHAR2,
    i_xmlnamespace      VARCHAR2   );
FUNCTION is_user_exists (i_emp_id IN NUMBER
,i_source_asset_id IN deal.deal_source_cd%TYPE --Added for US-9408 --> Encore Retirement  
)
RETURN VARCHAR2;
PROCEDURE  ins_deal_pl(i_bd_id IN NUMBER,
    i_deal_creation_guid IN VARCHAR2,
    i_xmlnamespace   IN   VARCHAR2,
    i_region_cd    IN VARCHAR2,
    i_region_pct in number
    );
    PROCEDURE update_guid_for_errors (
    i_deal_creation_guid varchar2,
    i_bd_id numeric,
    i_bd_nr numeric,
    i_bd_version_nr numeric);
    procedure sendquote(i_bd_id number,i_bd_nr number,i_bd_version_nr number ,
    i_quote_user_id varchar2,
    i_quote_send_pdf_fl varchar2,
    i_quote_send_txt_fl varchar2,
    i_gen_opg_fl varchar2,
o_quote_sent out varchar2,
o_next_opg_num out deal.opg_num%type
);
procedure calculate_Deal_Disc_Margin_PCT
(i_bd_id number );
procedure recalc_running_totals (i_bd_id number);
function CHECK_HIGH_RISK_PLPF(I_BD_ID number) return varchar2;
function CHECK_LINE_ITEM_MARGIN_RISK (I_BD_ID number) return varchar2;
function GETLATEST_VER_BD_ID (I_BD_ID number) return number;
function getValid_Eclipse_UserID (i_user_hp_emp_nr number,o_errors out varchar2) return varchar2;

PROCEDURE  ins_competitors(i_bd_id IN NUMBER,
    i_deal_creation_guid IN VARCHAR2,
    I_XMLNAMESPACE   in   varchar2
    );
procedure Unauthorized_Zero_version_deal (i_bd_nr number);
procedure new_deal_quoted_xml (p_bd_id IN NUMBER,
                                                                            p_out_errmsg OUT VARCHAR2);
---Addded on 01-Feb-2012 to test send quote
PROCEDURE sendquotelight(
    i_bd_nr             NUMBER,
    o_quote_sent OUT VARCHAR2
    );
function isEUVReasonRequired(i_bus_model_cd bus_model_euv.bus_model_cd%type, i_country_cd bus_model_euv.cntry_cd%type,i_euv_reason_cd bus_model_euv.reason_cd%type) return number;
 PROCEDURE add_deal_comments( i_deal_creation_guid IN VARCHAR2,
                                                                P_RESULTS OUT SYS_REFCURSOR);
PROCEDURE set_dct_status (i_bd_id number,   I_DEAL_CREATION_GUID varchar, i_o_DCTExpireThresholdPct out numeric);
FUNCTION is_oe_user_exists(i_bd_id NUMBER,i_emp_nr NUMBER)
RETURN VARCHAR2;
FUNCTION add_reseller_a_new(
    i_deal_creation_guid IN VARCHAR2,
    i_xmlnamespace      VARCHAR2,
    i_bd_id             NUMERIC,
    i_country_cd        VARCHAR2,
    i_region_cd         VARCHAR2,
    i_bus_model_cd      VARCHAR2,
    i_rslr_added_emp_nr NUMERIC,
    o_error_message out varchar2)
  RETURN VARCHAR2 ;
  FUNCTION add_reseller_b_new(
    i_deal_creation_guid IN VARCHAR2,
    i_xmlnamespace      VARCHAR2,
    i_bd_id             NUMERIC,
    i_country_cd        VARCHAR2,
    i_region_cd         VARCHAR2,
    i_bus_model_cd      VARCHAR2,
    i_rslr_added_emp_nr NUMERIC ,
    o_error_message out varchar2)
  RETURN VARCHAR2;
 FUNCTION convert_to_blob(i_cmnt clob)--(i_cmnt varchar2)
 RETURN BLOB;
 FUNCTION replace_special_chars( i_text in VARCHAR2)
 RETURN VARCHAR2;
  FUNCTION replace_special_chars( i_text in CLOB)
 RETURN CLOB;
 PROCEDURE get_deal_details(p_bd_id IN NUMBER,p_deal_header OUT rctype,p_deal_won_lost OUT rctype,
                                            p_deal_euv_details OUT rctype, p_cust_details OUT rctype,p_user_details OUT rctype,
                                            p_agent_incentive_details OUT rctype,p_comp_plpn OUT rctype,p_comp_pl OUT rctype,
                                            p_affiliate_deatils OUT rctype, p_rslra_details OUT rctype,p_rslrb_details OUT rctype );
PROCEDURE ins_deal_timings(p_bd_id IN deal_timings.bd_id%type,
                                         --   p_seq_nr IN deal_timings.seq_nr%type,
                                            p_start_time_gmt DATE,
                                            p_start_emp_nr IN deal_timings.start_hp_emp_nr%type,
                                            p_stop_time_gmt DATE,
                                            p_stop_emp_nr deal_timings.stop_hp_emp_nr%type,
                                            p_reason_cd deal_timings.reason_cd%type,
                                            p_stop_desc deal_timings.stop_description%type,
                                            p_stop_cd deal_timings.stop_code%type,
                                            p_start_cd deal_timings.start_code%type);
FUNCTION get_emp_nr(p_emp_mail IN employee.email_unix_addr_tx%type )
RETURN user_tab.user_hp_emp_nr%type;
FUNCTION Rollout_Qty_BMI(p_bigin_dt date,p_end_dt date,p_qty NUMBER)
RETURN VARCHAR2;
Function isDealReadyForNewVersion (p_source_bd_nr deal.bd_nr%type,  p_error_message out varchar2)
return varchar2;
Function LockDeal (p_source_bd_nr deal.bd_nr%type,p_lock_Deal_User_id user_tab.user_id%type,  p_error_message out varchar2)
return varchar2;
Procedure BMICreateNewVersion (
        i_deal_creation_guid     IN     VARCHAR2,
        p_result                 OUT SYS_REFCURSOR,
        p_prod_details             OUT SYS_REFCURSOR );
function UnlockDeal (p_source_bd_nr deal.bd_nr%type,p_error_message out varchar2)
return varchar2;
Procedure add_LineItems(i_deal_creation_guid IN VARCHAR2,
                                    i_xmlnamespace VARCHAR2,
                                    i_bd_id number,
                                    i_add_date_range VARCHAR2,
                                    p_result OUT SYS_REFCURSOR);
/*procedure Add_Bundle_Products (
    i_deal_creation_guid  IN  VARCHAR,
    i_xmlnamespace        IN  varchar,
    i_deal_creator_emp_nr IN  deal.init_hp_emp_nr%type,
    i_bd_id               IN  DEAL.BD_ID%TYPE,
    i_bd_nr               IN  DEAL.BD_NR%TYPE,
    i_bd_version_nr       IN  DEAL.BD_VERSION_NR%TYPE,
    i_dealsourcecd        IN  VARCHAR,
    i_dealvertocreate     IN  NUMBER,
    i_deal_begin_date     IN  DEAL.BEG_DT%TYPE,
    i_deal_end_date       IN  deal.end_dt%type,
    i_dealapprfl          IN  VARCHAR2,
    i_dealquotefl        IN  VARCHAR2,
    i_dealroutefl       IN  VARCHAR2,
    I_COUNTRY_CD DEAL.CONTROL_CNTRY_CD%TYPE,
    I_price_term_cd deal.price_term_cd%type,
    i_price_list_cd deal.price_list_cd%type,
    i_currency_cd deal.curr_cd%type,
    i_dealsourcedealtype deal.deal_source_deal_type%type,
    i_dealsourcekeyval deal.deal_source_keyval%type,
    l_hierarchy_cd deal_matrix.hierarchy_cd%type
);
*/
procedure add_bundle_products(
i_deal_creation_guid IN VARCHAR2,
  i_xmlnamespace        IN  varchar,
    i_deal_creator_emp_nr IN  deal.init_hp_emp_nr%type,
    i_bd_id               IN  DEAL.BD_ID%TYPE,
    i_bd_nr               IN  DEAL.BD_NR%TYPE,
    i_bd_version_nr       IN  DEAL.BD_VERSION_NR%TYPE,
    i_dealsourcecd        IN  VARCHAR,
    i_dealvertocreate     IN  NUMBER,
    i_deal_begin_date     IN  DEAL.BEG_DT%TYPE,
    i_deal_end_date       IN  deal.end_dt%type,
    i_dealapprfl          IN  VARCHAR2,
    i_dealquotefl        IN  VARCHAR2,
    i_dealroutefl       IN  VARCHAR2,
    I_COUNTRY_CD DEAL.CONTROL_CNTRY_CD%TYPE,
    I_price_term_cd deal.price_term_cd%type,
    i_price_list_cd deal.price_list_cd%type,
    i_currency_cd deal.curr_cd%type,
    i_dealsourcedealtype deal.deal_source_deal_type%type,
    i_dealsourcekeyval deal.deal_source_keyval%type,
    i_hierarchy_cd deal_matrix.hierarchy_cd%type,
    i_busmodelcd DEAL.BUS_MODEL_CD%TYPE );

    PROCEDURE update_line_disc_scale (l_bd_id IN NUMBER,
                                    g_deal_creation_guid IN VARCHAR2,
                                    I_ERROR_MESSAGE OUT VARCHAR2);
PROCEDURE insert_deal_pl(l_bd_id IN NUMBER,
                        l_region IN VARCHAR2,
                        g_deal_creation_guid IN VARCHAR2,
                        I_ERROR_MESSAGE OUT VARCHAR2);
PROCEDURE bundle_high_list_price(L_new_BD_ID IN NUMBER,o_error_message OUT varchar2);
PROCEDURE update_agent_aprvl_fl(l_bd_id IN NUMBER);
PROCEDURE approve_deal ( l_bd_id IN NUMBER,l_is_all_lines_authorized OUT VARCHAR2);
  PROCEDURE quote_deal(l_bd_id IN NUMBER,
                        l_bd_nr IN NUMBER,
                        L_BD_VERSION_NR IN NUMBER,
                      l_dealquote_fl IN VARCHAR2,
                      l_dealapprfl IN VARCHAR2,
                      l_is_all_lines_authorized IN VARCHAR2,
                       L_QUOTED_BY_USER_ID IN VARCHAR2,
                       L_QUOTEDBYEMPNR IN NUMBER,
                      L_HIGH_RISK_FL IN VARCHAR2,
                      l_GenerateOPGNbrFl varchar2,
                       I_EUV_AT_WON_FL IN VARCHAR2
                      );
 PROCEDURE route_deal(l_bd_id IN NUMBER,
                                l_dealroutefl IN VARCHAR2,
                                l_dealvertocreate IN NUMBER,
                                l_high_risk_fl IN VARCHAR2,
                                l_dealsourcedealtype IN deal.deal_source_deal_type%TYPE,
                                l_euv_at_won_fl IN VARCHAR2,
                                l_eclipse_user_id IN user_tab.user_id%type
                                );
Procedure UpdateBundles(i_deal_creation_guid  IN varchar2,
                            i_xmlnamespace        IN  varchar2,
                            i_bd_id               IN  DEAL.BD_ID%TYPE,
                            i_bd_nr               IN  DEAL.BD_NR%TYPE,
                            i_bd_version_nr       IN  DEAL.BD_VERSION_NR%TYPE,
                            i_add_date_range IN VARCHAR2);

PROCEDURE EDPCreateNewDeal(
    i_deal_creation_guid IN VARCHAR2,
    p_result OUT sys_refcursor,
    p_prod_details OUT SYS_REFCURSOR );
procedure update_error_tables
(
i_deal_creation_guid IN VARCHAR2,
 i_new_bd_id               IN  DEAL.BD_ID%TYPE,
 i_new_bd_version_nr       IN  DEAL.BD_VERSION_NR%TYPE,
                            i_source_bd_nr               IN  DEAL.BD_NR%TYPE,
                            i_source_bd_version_nr       IN  DEAL.BD_VERSION_NR%TYPE,
                            i_source_bd_id       IN  DEAL.BD_ID%TYPE

                            );

FUNCTION add_reseller_a_BMI_new(
    i_deal_creation_guid IN VARCHAR2,
    i_xmlnamespace      VARCHAR2,
    i_bd_id             NUMERIC,
    i_country_cd        VARCHAR2,
    i_region_cd         VARCHAR2,
    i_bus_model_cd      VARCHAR2,
    i_rslr_added_emp_nr NUMERIC,
    o_error_message OUT VARCHAR2)
  RETURN VARCHAR2;

FUNCTION add_reseller_b_BMI_new(
    i_deal_creation_guid IN VARCHAR2,
    i_xmlnamespace      VARCHAR2,
    i_bd_id             NUMERIC,
    i_country_cd        VARCHAR2,
    i_region_cd         VARCHAR2,
    i_bus_model_cd      VARCHAR2,
    i_rslr_added_emp_nr NUMERIC ,
    i_add_additional_resellers IN VARCHAR2,
    o_error_message out varchar2)
  RETURN VARCHAR2;

  PROCEDURE get_default_values( i_deal_creation_guid IN VARCHAR2,
                                  out_default_bus_model_cd OUT VARCHAR2,
                                   out_split_deal_fl OUT VARCHAR2,
                                   out_value_default_bm OUT VARCHAR2,
                                   out_volume_default_bm OUT VARCHAR2,
                                   out_mc_charge OUT VARCHAR2,
                                   out_value_mc_charge OUT VARCHAR2,
                                   out_volume_mc_charge OUT VARCHAR2,
                                   out_bus_group OUT VARCHAR2,
                                   out_bus_unit OUT VARCHAR2,
                                   out_cust_industry OUT VARCHAR2,
                                   out_cust_segment OUT VARCHAR2,
                                   out_routing_ind OUT VARCHAR2,
                                   out_value_routing_Ind OUT VARCHAR2,
                                   out_volume_routing_ind OUT VARCHAR2,
                                   out_asap_indicator OUT VARCHAR2,
                                   out_max_pl OUT VARCHAR2,
                                   out_deal_default_duration_days OUT NUMBER,
                                   --out_euvreasoncd OUT VARCHAR2,
                                   --out_euvtypecd OUT VARCHAR2,
                                   out_value_refcursor OUT SYS_REFCURSOR,
                                   out_volume_refcursor OUT SYS_REFCURSOR,
                                   out_error_messages OUT SYS_REFCURSOR
                                  , out_deal_tenantid OUT VARCHAR2 ---Added for SMO
                                   );

PROCEDURE GET_DEFAULT_ROUTINGINDICATOR (a_bd_id     IN   PLS_INTEGER
                          , o_routingIndicatorCD   OUT  VARCHAR2);
PROCEDURE CLEAR_BUNDLE_LINE_AUTH(i_deal_creation_guid varchar2, i_xmlnamespace VARCHAR2,
i_bd_id numeric,i_bundle_header_line_nr numeric ,i_bundle_index numeric,i_bundle_source varchar2);

PROCEDURE BMI_insert_prod_line(
      i_bd_id                   NUMBER,
      i_bd_nr                   NUMBER,
      i_bd_version_nr           NUMBER,
      i_line_prog_cd            VARCHAR2,
      i_deal_prog_cd            VARCHAR2,
      i_bdme_aprvl_cd           VARCHAR2,
      i_quote_dist_cd           VARCHAR2,
      i_euv_stat_code           VARCHAR2,
      i_high_risk_fl            VARCHAR2,
      i_risk_reasion_desc       VARCHAR2,
      i_risk_desc               VARCHAR2,
      i_deal_creation_guid      VARCHAR2,
      i_countrycd               VARCHAR2,
      i_pricelistcd             VARCHAR2,
      i_currencycd              VARCHAR2,
      i_pricetermcd             VARCHAR2,
      i_prod_string             VARCHAR2,
      i_globai_fl               VARCHAR2,
      i_hierarchy_cd            VARCHAR2,
      i_enddate                 VARCHAR2,
      i_line_type_cd            VARCHAR2,
      i_prod_list_price         NUMBER,
      i_prod_auth_basis_text    VARCHAR2,
      i_prod_qty                NUMBER,
      i_bdnetamt                NUMBER,
      i_auth_emp_nr             NUMBER,
      i_auth_mc_hp_emp_nr       NUMBER,
      i_line_added_by_emp_nr    NUMBER,
      i_pricingtypecd           VARCHAR2,
      i_line_nr                 NUMBER,
      i_begindate               VARCHAR2,
      i_add_bundles             VARCHAR2,
      i_add_bundleHeader        VARCHAR2,
      i_config_src              VARCHAR2,
      i_config_id              VARCHAR2,-- NUMBER,  commented as part of Cr5020
      i_source_config_id        VARCHAR2,
      i_stddiscpct              number,
      i_line_item_nr_for_bundle number,
      i_auth_stat_cd varchar2,
      i_opt_cd  varchar2,
      I_ROLLOUTMONTHQTYS varchar2,
      --I_AUTHDATEGMT varchar2,
      --i_auth_mc_date varchar2,
      I_AUTHDATEGMT DATE, --Changed as per CR:236715
      i_auth_mc_date DATE, --Changed as per CR:236715
      i_dealsourcedealtype varchar2,
      i_bd_line_qty_for_hdr_sku number      ,
      i_bundle_desc varchar2,
      I_SKU_PL                      varchar2,   ---Added for CR3236
      I_BD_HDR_LINE_AUTH_BD_NET LINE_DISC_SCALE.RQST_BD_NET_PRC_AM%type,
      i_prod_cost_price number,
      i_prod_cost_price_hdr_prod number,
      i_busmodelcd varchar2,  ---Added  for CR 4774
      i_minorder_qty VARCHAR2 ,---Added for CR 4735
      i_line_auth_type line_item.line_auth_type%type,--added for new auth changes
      i_line_authdesc  VARCHAR2,
      i_line_AuthStat  bundle_line.ITEM_PROG_CD%type,
      i_line_AuthDtGMT DATE,
      o_create_new_version out varchar,
      i_banded_fl varchar2,
      i_bmi_doc_no varchar2,
      i_prod_desc  LINE_ITEM.PROD_GNRC_DESC_TX%TYPE,  --Added by Ramesh on 17-Feb-2014 for proddesc for R8
      i_EXT_PRE_APPRV_PRC_AM LINE_DISC_SCALE.EXT_PRE_APPRV_PRC_AM%TYPE,
      i_total_hdr_listprice_value number,
      i_total_hdr_bdnet_value number,
      I_DisplayCompPrcFl VARCHAR2,
      i_guidance_available_fl VARCHAR2,
      i_guidance_details_id NUMBER,
      i_guidance_expert_pct NUMBER,
      i_guidance_floor_pct NUMBER,
      i_guidance_typical_pct NUMBER,
      i_guidance_last_refresh_dt VARCHAR2,
      i_non_discount_Fl VARCHAR2
    ,i_InstantPrcMethod  bundle_line.INSTANT_PRC_METHOD%TYPE  --Added for UsS7301
    ,i_InstantPrcAmount  bundle_line.INSTANT_PRC_AMT%TYPE --Added for US 7301
    ,i_ContraAMt bundle_line_contra.CONTRA_AMT%TYPE ---Added for US 7301
    , i_use_ext_list_price    GT_XML_line_item.use_ext_list_price%TYPE --New variable added by Lakshmi for HP SW Project
      );

PROCEDURE add_date_range( in_line_nr IN NUMBER,
                          in_bd_id IN NUMBER,
                          out_status OUT VARCHAR2);
PROCEDURE update_rollout(IN_sku IN VARCHAR2,
                         l_begindate IN DATE,
                         l_enddate IN DATE,
                         IN_QTY IN NUMBER,
                         IN_ROLLOUTMONTHQTYS IN VARCHAR2,
                         IN_orderminqty IN NUMBER,
                         IN_OPTCD in VARCHAR2,
                         in_bd_id IN NUMBER,
                         in_line_nr IN NUMBER,
                         out_status OUT VARCHAR2);
PROCEDURE update_date_range (l_deal_creation_guid IN VARCHAR2,
                               l_line_nr in number,
                             in_bd_id     IN NUMBER);
Procedure GenerateOPG (I_BD_ID NUMBER ,  o_next_opg_num out VARCHAR2,
      O_ERRORS out varchar2);
  procedure UpdateDealDettailsForNewVersio(
  i_deal_creation_guid IN VARCHAR2,
  i_xmlnamespace      VARCHAR2,
  i_bd_id IN NUMBER,
  o_success_fl OUT varchar2
  );

PROCEDURE split_value_volume_products (IN_deal_creation_guid IN VARCHAR2);
                                                        --out_value_products OUT SYS_REFCURSOR,
                                                        --out_volume_products OUT SYS_REFCURSOR);

PROCEDURE delete_resellers(i_deal_creation_guid IN VARCHAR2,
                            i_bd_id IN NUMBER,
                            i_xmlnamespace      VARCHAR2,
                            o_error_message OUT VARCHAR2);

FUNCTION get_max_pl_bmi (IN_deal_creation_Guid IN VARCHAR2)
                RETURN VARCHAR2 ;

FUNCTION total_value_of_deal (IN_deal_creation_Guid IN VARCHAR2)
                RETURN NUMBER ;

FUNCTION check_ismultibg_deal (in_Bd_id IN NUMBER)
   RETURN VARCHAR2;

PROCEDURE update_deal_enddate ( in_bd_id IN NUMBER,
                    l_deal_creation_guid IN VARCHAR2,
                    o_error_message OUT VARCHAR2);

PROCEDURE log_default_value_errors ( in_deal_creation_guid IN VARCHAR2,
                                     in_error_message IN VARCHAR2);
FUNCTION  is_emp_bmi_default (i_emp_nr  IN NUMBER,
                                                  i_source_asset_id IN deal.deal_source_cd%TYPE --Added for US-9408 --> Encore Retirement  
                                                    )
   RETURN VARCHAR2;

/* PROCEDURE missing_entry(in_eng_model IN VARCHAR2,
                        in_country_cd IN VARCHAR2,
                        in_region_cd IN VARCHAR2,
                        in_lead_bus_grp IN VARCHAR2 DEFAULT '*',
                        in_prod_line_cd IN VARCHAR2 DEFAULT '*'); */

PROCEDURE get_contracts_for_pl(l_ppro_id IN VARCHAR2,
                                l_countrycd IN VARCHAR2,
                                  l_busmodelcd IN VARCHAR2,
                                  --l_engagement_model IN VARCHAR2,
                                  l_engagement_model IN NUMBER,
                                  in_max_pl IN VARCHAR2,
                                  in_region_cd IN VARCHAR2,
                                  in_supplies_only_fl IN VARCHAR2,
                                  out_contract OUT VARCHAR2,
                                  status_message OUT VARCHAR2);

PROCEDURE insert_BMI_Default_VOL_RSLR(l_bd_id IN NUMBER,
                                      l_rslr_added_emp_nr IN NUMBER,
                                      status_message OUT VARCHAR2
                                      );
FUNCTION  fcalcRqstDiscPCT(
i_bd_net  NUMERIC,
I_LIST_PRICE NUMERIC,
I_STD_DISC_PCT NUMERIC)
RETURN PKGEDMSDEALCREATIONV2_R14.decimal_type;
FUNCTION  fcalcRqstMarginPCT(
i_bd_net  NUMERIC,
i_cost_price  NUMERIC
)
RETURN PKGEDMSDEALCREATIONV2_R14.decimal_type;
Function UpdateHDRPricingValues
(i_bd_id deal.bd_id%type )
return varchar2;

PROCEDURE update_bundle_line_prices(
i_bundle_index IN VARCHAR2,
i_bundle_source IN VARCHAR2,
i_bd_id IN NUMBER,
i_bundle_line_nr IN NUMBER,
i_deal_creation_guid IN VARCHAR2,
i_std_disc_pct line_disc_scale.high_rslr_a_sd_pc%type,
I_auth_dt_gmt IN VARCHAR2,
i_auth_mc_hp_emp_nr in number,
i_bmi_generic_emp_nr IN NUMBER
);

PROCEDURE update_remaining_amt(in_bd_id IN NUMBER);

l_price gt_product_bundles_prices.price%TYPE;
l_prod_desc gt_product_bundles_prices.prod_desc%TYPE;
l_prod_nr gt_product_bundles_prices.prod_nr%TYPE;
l_stat gt_product_bundles_prices.stat%TYPE;
l_prod_line gt_product_bundles_prices.prod_line%TYPE;
l_non_discount_fl gt_product_bundles_prices.non_discount_fl%TYPE;
l_ref_price_fl gt_product_bundles_prices.ref_price_fl%TYPE;
l_prod_family gt_product_bundles_prices.prod_family%TYPE;

PROCEDURE get_list_prices_from_gypsy
        (i_countrycd IN VARCHAR2,
        i_pricelistcd IN VARCHAR2,
        i_currencycd IN VARCHAR2,
        i_pricetermcd IN VARCHAR2,
        i_deal_creation_guid IN VARCHAR2,
        i_GlobalFl IN VARCHAR2,
        i_hierarchy_cd IN VARCHAR2,
        i_enddate IN DATE);


PROCEDURE get_default_values_new ( i_deal_creation_guid IN VARCHAR2,
                                   out_default_bus_model_cd OUT VARCHAR2,
                                   out_split_deal_fl OUT VARCHAR2,
                                   out_value_default_bm OUT VARCHAR2,
                                   out_volume_default_bm OUT VARCHAR2,
                                   out_mc_charge OUT VARCHAR2,
                                   out_value_mc_charge OUT VARCHAR2,
                                   out_volume_mc_charge OUT VARCHAR2,
                                   out_bus_group OUT VARCHAR2,
                                   out_bus_unit OUT VARCHAR2,
                                   out_cust_industry OUT VARCHAR2,
                                   out_cust_segment OUT VARCHAR2,
                                   out_routing_ind OUT VARCHAR2,
                                   out_value_routing_Ind OUT VARCHAR2,
                                   out_volume_routing_ind OUT VARCHAR2,
                                   out_asap_indicator OUT VARCHAR2,
                                   out_max_pl OUT VARCHAR2,
                                   out_deal_default_duration_days OUT NUMBER,
                                   out_value_refcursor OUT SYS_REFCURSOR,
                                   out_volume_refcursor OUT SYS_REFCURSOR,
                                   out_error_messages OUT SYS_REFCURSOR
                                  , out_deal_tenantid OUT VARCHAR2 ---Added for SMO
                                    );

PROCEDURE GET_DEFAULT_BM (
   i_ENGAGEMENT_MODEL  IN  DEFAULT_BM.ENGAGEMENT_MODEL%TYPE
  ,i_COUNTRY_CD  IN DEFAULT_BM.COUNTRY_CD%TYPE   default null
  ,i_REGION_CD  IN DEFAULT_BM.REGION_CD%TYPE     default null
  ,i_LEAD_BUS_GRP IN  DEFAULT_BM.LEAD_BUS_GRP%TYPE     default null
  ,i_BUS_UNIT_CD IN  DEFAULT_BM.BUS_UNIT_CD%TYPE     default null
  ,i_PROD_LINE_CD IN DEFAULT_BM.PROD_LINE_CD%TYPE     default null
  ,i_VALUE_ONLY_FL IN  DEFAULT_BM.VALUE_ONLY_FL%TYPE     default null
  ,i_VOLUME_ONLY_FL IN  DEFAULT_BM.VOLUME_ONLY_FL%TYPE    default null
  ,i_Deal_Has_CTO_Config_Fl  IN   DEFAULT_BM.Deal_Has_CTO_Config_Fl%TYPE     default null
  ,i_tenantid  IN  DEFAULT_BM.TENANTID%TYPE ---Added for SMO changes
  ,i_source_asset_id IN edms_source_asset.source_asset_id%TYPE --Added for US-9408 --> Encore Retirement  
  ,o_DEFAULT_BUS_MODEL    OUT  DEFAULT_BM.DEFAULT_BUS_MODEL%TYPE
  ,o_EXCEPTION_CD OUT  DEFAULT_BM.EXCEPTION_CD%TYPE
  ,o_VALUE_SPLIT_BM_CODE OUT  DEFAULT_BM.VALUE_SPLIT_BM_CODE%TYPE
  ,o_VOLUME_SPLIT_BM_CODE  OUT  DEFAULT_BM.VOLUME_SPLIT_BM_CODE%TYPE
  , o_data_found_rowid OUT ROWID
 ) ;

PROCEDURE GET_DEFAULT_MC_CODE (
i_engagement_model IN default_mc_charge.engagement_model%type  ,
i_COUNTRY_CD IN   default_mc_charge.country_cd%type   default null,
i_REGION_CD  IN default_mc_charge.region_cd%type   default null,
i_bus_model_cd  IN  default_mc_charge.bus_model_cd%type   default null,
i_Deal_Value_Greater_Than  IN  default_mc_charge.Deal_Value_Greater_Than%type  default null ,
i_Customer_Segment IN default_mc_charge.customer_segment%TYPE DEFAULT NULL,
i_Rebate_Type IN default_mc_charge.Rebate_Type%type  default null,
i_LEAD_bus_grp   IN default_mc_charge.lead_bus_grp%type    default null,
i_piu_flag   IN default_mc_charge.piu_flag%type   default null,
i_Deal_Has_CTO_Config_Fl IN   default_mc_charge.Deal_Has_CTO_Config_Fl%type   default null,
i_only_bu_exists_on_deal default_mc_charge.only_bu_exists_on_deal%type default null,
i_lead_bus_unit_cd IN default_mc_charge.lead_bus_unit_cd%TYPE DEFAULT NULL, -- New parameter added by Lakshmi for CR:180261- To consider Lead Bus Unit while deriving Default MC Charge
i_tenantid IN default_mc_charge.tenantid%type,----Added for SMO changes
i_source_asset_id IN edms_source_asset.source_asset_id%TYPE, --Added for US-9408 --> Encore Retirement
o_MC_CHARGE   OUT default_mc_charge.mc_charge%type
) ;

 PROCEDURE  GET_DEFAULT_ROUTING_INDICATOR (
  i_ENGAGEMENT_MODEL  IN  DEFAULT_BM.ENGAGEMENT_MODEL%TYPE
  ,  i_REGION_CD  IN DEFAULT_ROUTING_INDICATOR.REGION_CD%TYPE     default null
  ,i_COUNTRY_CD  DEFAULT_ROUTING_INDICATOR.COUNTRY_CD%TYPE
  ,i_BUS_MODEL_CD  IN  DEFAULT_ROUTING_INDICATOR.BUS_MODEL_CD%TYPE     default null
  ,i_CUST_SEG_CD   IN  DEFAULT_ROUTING_INDICATOR.CUST_SEG_CD%TYPE     default null
   ,i_tenantid IN DEFAULT_ROUTING_INDICATOR.TENANTID%TYPE---Added for SMO changes
  , o_Routing_Ind    OUT DEFAULT_ROUTING_INDICATOR.ROUTING_INDICATOR_CD%TYPE
 ) ;

l_rtm DEFAULT_BMI_EMPLOYEE.ROUTE_TO_MARKET%TYPE;


FUNCTION GET_DEFAULT_EMP_NR_FROM_EMAIL (in_won_lost_emp_email   IN VARCHAR2,
                                                                  l_control_cntry_cd IN VARCHAR2,
                                                                  l_region_cd IN VARCHAR2,
                                                                  l_rtm IN VARCHAR2
                                                                  ,l_source_asset_id IN VARCHAR2) --Added for US-9408 --> Encore Retirement  
RETURN NUMBER;

--PROCEDURE update_display_comp_prc_fl (in_bd_id IN NUMBER);

PROCEDURE send_mail(
i_from_address IN VARCHAR2,
i_to_address IN VARCHAR2,
i_email_subject IN VARCHAR2,
i_email_body IN VARCHAR2,
i_receipents IN VARCHAR2,
o_vError OUT VARCHAR2);

--by Harsh Shah 12/2/2014 for checking High Risk Reseller B
FUNCTION is_reseller_b_high_risk ( i_bd_id deal.bd_id%type, i_deal_creation_guid edms_deal_error_report.deal_creation_guid%type)
RETURN VARCHAR2;

--by Harsh Shah 23-Jan-2015, for performance Improvement
FUNCTION  Fill_Temp_Tables (i_guid varchar2, i_xmlnamespace varchar2) return varchar2;

--Below Procedure added by Lakshmi for US-7331- Eclipse Deal Sync Eclipse Processing
Procedure BMIUpdateDeal (
        i_deal_creation_guid     IN     VARCHAR2,
        p_result                 OUT SYS_REFCURSOR,
        p_prod_details             OUT SYS_REFCURSOR );

--Below Procedure added by Lakshmi for US-7331- Eclipse Deal Sync Eclipse Processing
PROCEDURE clear_auth(i_bd_id IN deal.bd_id%TYPE,
                                    i_line_nr IN NUMBER,
                                    i_deal_guid IN VARCHAR2);

--Below procedure added by Lakshmi for CR183981 - Taking Out PNs that are part of Autobundled Configs - They are completely deleted
PROCEDURE ReplaceBundles(
        i_deal_creation_guid IN VARCHAR2,
        i_xmlnamespace        IN  varchar,
        i_deal_creator_emp_nr IN  deal.init_hp_emp_nr%type,
        i_bd_id               IN  DEAL.BD_ID%TYPE,
        i_bd_nr               IN  DEAL.BD_NR%TYPE,
        i_bd_version_nr       IN  DEAL.BD_VERSION_NR%TYPE,
        i_dealsourcecd        IN  VARCHAR,
        i_dealvertocreate     IN  NUMBER,
        i_deal_begin_date     IN  DEAL.BEG_DT%TYPE,
        i_deal_end_date       IN  deal.end_dt%type,
        i_dealapprfl          IN  VARCHAR2,
        i_dealquotefl        IN  VARCHAR2,
        i_dealroutefl       IN  VARCHAR2,
        I_COUNTRY_CD DEAL.CONTROL_CNTRY_CD%TYPE,
        I_price_term_cd deal.price_term_cd%type,
        i_price_list_cd deal.price_list_cd%type,
        i_currency_cd deal.curr_cd%type,
        i_dealsourcedealtype deal.deal_source_deal_type%type,
        i_dealsourcekeyval deal.deal_source_keyval%type,
        i_hierarchy_cd deal_matrix.hierarchy_cd%type,
        i_busmodelcd DEAL.BUS_MODEL_CD%TYPE
)   ;
--Below procedure added by Lakshmi for CR183981 - Taking Out PNs that are part of Autobundled Configs - They are completely deleted
PROCEDURE replace_date_range( in_line_nr IN NUMBER,
                          in_bd_id IN NUMBER,
                          out_status OUT VARCHAR2);


PROCEDURE BMI_insert_prod_line_Replace
  (
    i_bd_id                   NUMBER,
    i_bd_nr                   NUMBER,
    i_bd_version_nr           NUMBER,
    i_line_prog_cd            VARCHAR2,
    i_deal_prog_cd            VARCHAR2,
    i_bdme_aprvl_cd           VARCHAR2,
    i_quote_dist_cd           VARCHAR2,
    i_euv_stat_code           VARCHAR2,
    i_high_risk_fl            VARCHAR2,
    i_risk_reasion_desc       VARCHAR2,
    i_risk_desc               VARCHAR2,
    i_deal_creation_guid      VARCHAR2,
    i_countrycd               VARCHAR2,
    i_pricelistcd             VARCHAR2,
    i_currencycd              VARCHAR2,
    i_pricetermcd             VARCHAR2,
    i_prod_string             VARCHAR2,
    i_globai_fl               VARCHAR2,
    i_hierarchy_cd            VARCHAR2,
    i_enddate                 VARCHAR2,
    i_line_type_cd            VARCHAR2,
    i_prod_list_price         NUMBER,
    i_prod_auth_basis_text    VARCHAR2,
    i_prod_qty                NUMBER,
    i_bdnetamt                NUMBER,
    i_auth_emp_nr             NUMBER,
    i_auth_mc_hp_emp_nr       NUMBER,
    i_line_added_by_emp_nr    NUMBER,
    i_pricingtypecd           VARCHAR2,
    i_line_nr                 NUMBER,
    i_begindate               VARCHAR2,
    i_add_bundles             VARCHAR2,
    i_add_bundleheader        VARCHAR2,
    i_config_src              VARCHAR2,
    i_config_id               VARCHAR2,-- NUMBER,  commented as part of CR5020
    i_source_config_id        VARCHAR2,
    i_stddiscpct              NUMBER,
    i_line_item_nr_for_bundle NUMBER,
    i_auth_stat_cd            VARCHAR2,
    i_opt_cd                  VARCHAR2,
    I_ROLLOUTMONTHQTYS        VARCHAR2,
    i_authdategmt             VARCHAR2,
    i_auth_mc_date            VARCHAR2,
    i_dealsourcedealtype      VARCHAR2,
    i_bd_line_qty_for_hdr_sku NUMBER,
    i_bundle_desc             VARCHAR2,
    i_sku_pl                  VARCHAR2, ---Added for CR3236
    I_BD_HDR_LINE_AUTH_BD_NET LINE_DISC_SCALE.RQST_BD_NET_PRC_AM%type,
    I_PROD_COST_PRICE          NUMBER,
    I_PROD_COST_PRICE_HDR_PROD NUMBER,
    i_busmodelcd               VARCHAR2,          ---Added  for CR 4774
    i_minorder_qty             VARCHAR2 ,         ---Added for CR4735
    i_line_auth_type line_item.line_auth_type%type,--added for new auth changes
    i_line_authdesc VARCHAR2 ,
    i_line_AuthStat bundle_line.ITEM_PROG_CD%type,
    i_line_AuthDtGMT DATE,
    o_create_new_version OUT VARCHAR,
    i_banded_fl varchar2,
    i_bmi_doc_no varchar2,
    i_prod_desc  LINE_ITEM.PROD_GNRC_DESC_TX%TYPE , --Added by Ramesh on 17-Feb-2014 for R8
    i_EXT_PRE_APPRV_PRC_AM line_disc_scale.EXT_PRE_APPRV_PRC_AM%TYPE,
    i_total_hdr_listprice_value number,
    i_total_hdr_bdnet_value number,
      I_DisplayCompPrcFl VARCHAR2,--Added for US6037 --> Show Component Level Pricing
      i_guidance_available_fl VARCHAR2,--Added by Lakshmi for CR6012
      i_guidance_details_id NUMBER,--Added by Lakshmi for CR6012
      i_guidance_expert_pct NUMBER,--Added by Lakshmi for CR6012
      i_guidance_floor_pct NUMBER,--Added by Lakshmi for CR6012
      i_guidance_typical_pct NUMBER,--Added by Lakshmi for CR6012
      i_guidance_last_refresh_dt VARCHAR2,--Added by Lakshmi for CR6012
      i_non_discount_Fl VARCHAR2,
      i_scale_id IN NUMBER
     ,i_InstantPrcMethod  bundle_line.INSTANT_PRC_METHOD%TYPE  --Added for UsS7301
    ,i_InstantPrcAmount  bundle_line.INSTANT_PRC_AMT%TYPE --Added for US 7301
    ,i_ContraAMt bundle_line_contra.CONTRA_AMT%TYPE ---Added for US 7301
    ,i_use_ext_list_price    GT_XML_line_item.use_ext_list_price%TYPE --New variable added by Lakshmi for HP SW Project
  );

procedure replace_bundle_products(
    i_deal_creation_guid IN VARCHAR2,
  i_xmlnamespace        IN  varchar,
    i_deal_creator_emp_nr IN  deal.init_hp_emp_nr%type,
    i_bd_id               IN  DEAL.BD_ID%TYPE,
    i_bd_nr               IN  DEAL.BD_NR%TYPE,
    i_bd_version_nr       IN  DEAL.BD_VERSION_NR%TYPE,
    i_dealsourcecd        IN  VARCHAR,
    i_dealvertocreate     IN  NUMBER,
    i_deal_begin_date     IN  DEAL.BEG_DT%TYPE,
    i_deal_end_date       IN  deal.end_dt%type,
    i_dealapprfl          IN  VARCHAR2,
    i_dealquotefl        IN  VARCHAR2,
    i_dealroutefl       IN  VARCHAR2,
    I_COUNTRY_CD DEAL.CONTROL_CNTRY_CD%TYPE,
    I_price_term_cd deal.price_term_cd%type,
    i_price_list_cd deal.price_list_cd%type,
    i_currency_cd deal.curr_cd%type,
    i_dealsourcedealtype deal.deal_source_deal_type%type,
    i_dealsourcekeyval deal.deal_source_keyval%type,
    i_hierarchy_cd deal_matrix.hierarchy_cd%type,
    i_busmodelcd DEAL.BUS_MODEL_CD%TYPE );

    Function GET_TENANTCD_FROM_BG ( i_lead_BG IN deal.lead_bus_grp%type) RETURN VARCHAR2;

  PROCEDURE get_default_values_2 (i_deal_creation_guid IN VARCHAR2,
                                                   out_default_bus_model_cd OUT VARCHAR2,
                                                   out_split_deal_fl OUT VARCHAR2,
                                                   out_value_default_bm OUT VARCHAR2,
                                                   out_volume_default_bm OUT VARCHAR2,
                                                   out_mc_charge OUT VARCHAR2,
                                                   out_value_mc_charge OUT VARCHAR2,
                                                   out_volume_mc_charge OUT VARCHAR2,
                                                   out_routing_ind OUT VARCHAR2,
                                                   out_value_routing_Ind OUT VARCHAR2,
                                                   out_volume_routing_Ind OUT VARCHAR2,
                                                   out_deal_default_duration_days OUT NUMBER,
                                                   out_error_messages OUT SYS_REFCURSOR,
                                                  out_deal_tenantid OUT VARCHAR2 ---Added for SMO
                                                   );

line_item_UPDATE_FAILED EXCEPTION; --Added for CR:255844

end  PKGEDMSDEALCREATIONV2_EDP;

/