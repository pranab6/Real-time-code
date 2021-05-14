CREATE OR REPLACE PACKAGE BODY PREEVISION.NESTOR_BENUTZER_KONTEXT AS

  gACCOUNT_ID EDM_GRANTEES.GRANTEE_ID%TYPE;

/******************************************************************************/
/* Getterroutinen zum Lesen der allg. Variablen.                              */
/******************************************************************************/
function F_EDM_GET_ACCOUNT_ID
         return varchar2 is
begin
  return gACCOUNT_ID;
end ;

--------------------------------------------
function F_EDM_INTERNAL_SET_USER
         (EDM_USER        in VARCHAR2
         )return INTEGER is
  RET               INTEGER := 1;
  I                 PLS_INTEGER;
  J                 PLS_INTEGER;
begin
  begin
    select GRANTEE_ID
      into gACCOUNT_ID
      from EDM_GRANTEES
     where NAME = replace(EDM_USER, 'OPS$')
       and DELETION_DATE is NULL;

  exception
    when NO_DATA_FOUND then
      RET := 10462;
      gACCOUNT_ID := NULL;
    when others then
      gACCOUNT_ID := NULL;
      RET := 5;
  end;
  return RET;
end F_EDM_INTERNAL_SET_USER;

procedure P_EDM_INTERNAL_SET_USER
         (EDM_USER VARCHAR2
         ) is
  RET INTEGER;
begin
  RET := F_EDM_INTERNAL_SET_USER(EDM_USER);
end P_EDM_INTERNAL_SET_USER;

/*******************************************************************************
** Die Funktion ist nur f�r Nutzer mit der Rolle NESTOR_SYS_VERWALTER
** ausf�hrbar. Die Zulassung zum Bereich wird nicht gepr�ft.
** Die Funktion setzt die aktive Rolle auf NESTOR_SYS_VERWALTER.
*******************************************************************************/
function F_NESTOR_SET_ADMIN_BEREICH
         (EDM_DOMAIN_ID in VARCHAR2
         )return NUMBER is
  RET            NUMBER := 1;
begin
  if EDM_DOMAIN_ID is NULL then
    RET:= 2;
    return RET;
  end if;

  /* Hat Benutzer die minimal erforderliche Rolle ?*/
  RET := EDM_ATOMIC_FCT_1.F_EDM_IS_SYS_ADMIN;
  if RET != 1 then return RET; end if;

  return RET;
end F_NESTOR_SET_ADMIN_BEREICH;

/******************************************************************************/
/* akt. User setzen                                                           */
/******************************************************************************/
function F_EDM_SET_USER
         (EDM_USER         in VARCHAR2
         ,EDM_MACHINE      in VARCHAR2
         ,EDM_THREAD_ID    in VARCHAR2 := null
          )return INTEGER is
  nRET      INTEGER := 1;
  rACCOUNT  EDM_GRANTEES%ROWTYPE;
begin
  if EDM_USER is NULL then
    nRET := 2;
    return nRET;
  end if;

  /* Hat Benutzer die minimal erforderliche Rolle ?*/
  /* hier wird nicht der logische User, sondern der DB-User gepr�ft */
  nRET := EDM_ATOMIC_FCT_1.F_EDM_GET_ACCOUNT(replace(USER, 'OPS$'), rACCOUNT);
  if    nRET  = 6 then nRET := 10462; return nRET; /*User existiert nicht */
  elsif nRET != 1 then                return nRET;
  end if;

  nRET := EDM_ATOMIC_FCT_1.F_EDM_IS_SYS_ADMIN(rACCOUNT.GRANTEE_ID);
  if nRET != 1 then return nRET; end if;

  -- activate user
  nRET := F_EDM_INTERNAL_SET_USER(EDM_USER);
  if nRET != 1 then
    P_EDM_INTERNAL_SET_USER(USER);
    return nRET;
  end if;

  DBMS_APPLICATION_INFO.SET_CLIENT_INFO(EDM_USER||'@'||EDM_MACHINE);
  DBMS_APPLICATION_INFO.SET_ACTION(EDM_THREAD_ID);

  return nRET;
end F_EDM_SET_USER;

/******************************************************************************/
/* Action zur�cksetzen                                                        */
/******************************************************************************/
function F_EDM_UNSET_ACTION return INTEGER is
  nRET      INTEGER := 1;
begin
  DBMS_APPLICATION_INFO.SET_ACTION(null);

  return nRET;
end F_EDM_UNSET_ACTION;

-------------------------------------------
-- Returns the system date converted to UTC
-------------------------------------------
function F_EDM_GET_UTC_SYS_DATE return date is
begin
  return cast(sys_extract_utc(cast(cast(systimestamp as timestamp with local time zone) as timestamp with time zone)) as date);
end;


begin
  P_EDM_INTERNAL_SET_USER(USER);
END NESTOR_BENUTZER_KONTEXT;
/
