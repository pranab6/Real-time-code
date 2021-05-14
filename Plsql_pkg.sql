CREATE OR REPLACE PACKAGE BODY PREEVISION.edm_admin_fct_2
AS
-----------------------------------------------------------------------------
-- reset model version to a specified number, removing all 'future' entries.
-----------------------------------------------------------------------------
   FUNCTION f_edm_reset_model_version (
      edm_domain_id          IN   nestor_bereich.domain_id%TYPE,
      sequence_to_reset_to   IN   edm_commit_history.sequence_nr%TYPE
   )
      RETURN NUMBER
   IS
      l_ret                     NUMBER                             := 1;
      l_domain_id              edm_object_data.domain_id%TYPE      := edm_domain_id;
      l_sequence_to_reset_to   edm_object_data.sequence_to%TYPE
                                                      := sequence_to_reset_to;
      l_infinity      CONSTANT edm_object_data.sequence_to%TYPE
                                                       := 9223372036854775807;
   BEGIN
      IF edm_atomic_fct_1.f_edm_is_domain_admin (edm_domain_id) != 1
      THEN
         RETURN 10385;
      END IF;

      --
      -- 1st phase: remove all entries from the runtime data that was created after the model
      -- version to reset to:
      --
      BEGIN
         -- delete context mappings
         DELETE edm_context_mapping
          WHERE domain_id = l_domain_id
            AND sequence_nr > l_sequence_to_reset_to;

         -- delete context paths, using attribute values via object id:
         DELETE FROM edm_context_path_data
               WHERE domain_id = l_domain_id
                 AND sequence_from > l_sequence_to_reset_to;

         -- delete attribute values:
         DELETE FROM edm_context_attribute_value CV
               WHERE domain_id = l_domain_id
                 AND CV.sequence_from > l_sequence_to_reset_to;

         -- delete relations:
         DELETE FROM edm_relation
               WHERE domain_id = l_domain_id
                 AND sequence_from > l_sequence_to_reset_to;

         -- delete version datas:
         DELETE FROM edm_v_version_data vd
               WHERE vd.domain_id = l_domain_id
                 AND sequence_from > l_sequence_to_reset_to;

         -- delete object data:
         DELETE FROM edm_v_object_data
               WHERE domain_id = l_domain_id
                 AND sequence_from > l_sequence_to_reset_to;

         -- clean up of unused key tables:
         DELETE FROM edm_context_path p
               WHERE p.domain_id = l_domain_id
                 AND NOT EXISTS (SELECT 1
                                   FROM edm_context_path_data pd
                                  WHERE pd.context_path_id = p.context_path_id
                                    AND pd.domain_id = l_domain_id)
                 AND NOT EXISTS (SELECT 1
                                   FROM edm_context_attribute_value pa
                                  WHERE pa.context_path_id = p.context_path_id
                                    AND pa.domain_id = l_domain_id);

         DELETE FROM edm_object o
               WHERE o.domain_id = l_domain_id
                 AND NOT EXISTS (SELECT 1
                                   FROM edm_object_data od
                                  WHERE od.object_id = o.object_id
                                    AND od.domain_id = l_domain_id)
                 AND o.object_id != 'TECHNICALROOTID';

         DELETE FROM edm_version v
               WHERE NOT EXISTS (SELECT 1
                                   FROM edm_version_data vd
                                  WHERE vd.version_id = v.version_id);

         -- remove object locks on the domain - we do not know what locks may be useful after the deletes:
         DELETE FROM edm_object_locks l
               WHERE domain_id = l_domain_id;

         -- remove all old commit history entries:
         DELETE FROM edm_commit_history h
               WHERE h.domain_id = l_domain_id
                 AND h.sequence_nr > l_sequence_to_reset_to;

         -- remove all old svn mapping entries:
         DELETE FROM edm_svn_mapping h
               WHERE h.domain_id = l_domain_id
                 AND h.sequence_nr > l_sequence_to_reset_to;

         --
         -- 2nd phase: set all runtime data that was finished after the point of time to return to to "unfinished"
         -- (infinite sequence to)
         --
         UPDATE edm_object_data
            SET sequence_to = l_infinity
          WHERE sequence_to BETWEEN l_sequence_to_reset_to AND l_infinity
            AND domain_id = l_domain_id;

         UPDATE edm_relation
            SET sequence_to = l_infinity
          WHERE sequence_to BETWEEN l_sequence_to_reset_to AND l_infinity
            AND domain_id = l_domain_id;

         UPDATE edm_context_attribute_value
            SET sequence_to = l_infinity
          WHERE sequence_to BETWEEN l_sequence_to_reset_to AND l_infinity
            AND domain_id = l_domain_id;

         UPDATE edm_context_path_data
            SET sequence_to = l_infinity
          WHERE sequence_to BETWEEN l_sequence_to_reset_to AND l_infinity
            AND domain_id = l_domain_id;

         UPDATE edm_version_data
            SET sequence_to = l_infinity
          WHERE sequence_to BETWEEN l_sequence_to_reset_to AND l_infinity
            AND domain_id = l_domain_id;
      END;

      RETURN l_ret;
   END f_edm_reset_model_version;

   -- copy a domain's data into another domain. Used for duplication when restoring.
   function f_edm_copy_model (
      edm_domain_id_src IN nestor_bereich.domain_id%TYPE,
      edm_domain_id_dst IN nestor_bereich.domain_id%TYPE
   )
     return NUMBER is
   begin
     -- create mapping for edm_version:
     insert into TMP_EDM_VERSION (VERSION_ID, VERSION_ID_NEW)
     select v.version_id , sys_guid()
       from EDM_VERSION v where v.VERSION_ID in (select vd.VERSION_ID from EDM_VERSION_DATA vd where vd.DOMAIN_ID = edm_domain_id_src);

     -- create mapping for edm_relation
     insert into TMP_EDM_RELATION (RELATION_ID, RELATION_ID_NEW)
     select RELATION_ID, sys_guid() from EDM_RELATION where DOMAIN_ID = edm_domain_id_src;

     -- copy data:
     update NESTOR_BEREICH
        set (META_MODEL, META_MODEL_VERSION, MAX_XMIID)
            = (select d1.META_MODEL, d1.META_MODEL_VERSION, d1.MAX_XMIID from NESTOR_BEREICH d1 where d1.DOMAIN_ID = edm_domain_id_src)
      where DOMAIN_ID = edm_domain_id_dst;

     -- commit history:
     insert into EDM_COMMIT_HISTORY (COMMIT_HISTORY_ID, SEQUENCE_NR, DOMAIN_ID, ACCOUNT_NAME, COMMIT_DATE, TAG_NAME, DESCRIPTION)
     select sys_guid(), h.SEQUENCE_NR, edm_domain_id_dst, h.ACCOUNT_NAME, h.COMMIT_DATE, h.TAG_NAME, h.DESCRIPTION
       from EDM_COMMIT_HISTORY h
      where h.DOMAIN_ID = edm_domain_id_src;

     -- rich texts
     insert into EDM_FILE_DATA (FILE_ID, FILE_DATA, DOMAIN_ID, FILE_LENGTH)
     select f.FILE_ID, f.FILE_DATA, edm_domain_id_dst, f.FILE_LENGTH
       from EDM_FILE_DATA f
      where f.DOMAIN_ID = edm_domain_id_src;

     -- versions (with mapping)
     insert into EDM_VERSION (VERSION_ID, EL_ID) (
     select /*+dynamic_sampling(tmp 0) use_hash(tmp v) full(tmp) index_ffs(v)*/ tmp.VERSION_ID_NEW, v.EL_ID
       from TMP_EDM_VERSION tmp, EDM_VERSION v where v.VERSION_ID = tmp.VERSION_ID);

     insert into EDM_VERSION_DATA(SEQUENCE_FROM, SEQUENCE_TO, VERSION_ID, DOMAIN_ID, VARIANT_ID, VARIANT_NAME, REVISION, SYSTEM_STATE, PREDECESSOR_1)
     select /*+dynamic_sampling(t 0) ordered use_nl(v t)*/
            v.SEQUENCE_FROM, v.SEQUENCE_TO, t.VERSION_ID_NEW, edm_domain_id_dst, v.VARIANT_ID, v.VARIANT_NAME, v.REVISION, v.SYSTEM_STATE,
            (select /*+dynamic_sampling(t1 0) nl_sj */ t1.VERSION_ID_NEW from TMP_EDM_VERSION t1 where t1.VERSION_ID = v.PREDECESSOR_1)
       from EDM_VERSION_DATA v, TMP_EDM_VERSION t
      where v.VERSION_ID = t.VERSION_ID and v.DOMAIN_ID = edm_domain_id_src;

     -- objects:
     insert into EDM_OBJECT (OBJECT_ID, DOMAIN_ID)
     select /*+index_ffs(o) */ o.OBJECT_ID, edm_domain_id_dst from EDM_OBJECT o where o.DOMAIN_ID = edm_domain_id_src;

     insert into EDM_OBJECT_DATA (SEQUENCE_FROM, SEQUENCE_TO, DOMAIN_ID, OBJECT_ID, TYPE_ID, IS_ROOT, VERSION_ID)
     select /*+index(o)*/ o.SEQUENCE_FROM, o.SEQUENCE_TO, edm_domain_id_dst, o.OBJECT_ID, o.TYPE_ID, o.IS_ROOT,
            (select /*+dynamic_sampling(t 0) nl_sj */ t.VERSION_ID_NEW from TMP_EDM_VERSION t where t.VERSION_ID = o.VERSION_ID)
       from EDM_OBJECT_DATA o
      where o.DOMAIN_ID = EDM_DOMAIN_ID_SRC;

     -- context path:
     insert into EDM_CONTEXT_PATH (CONTEXT_PATH_ID, DOMAIN_ID)
     select CONTEXT_PATH_ID, edm_domain_id_dst from EDM_CONTEXT_PATH where DOMAIN_ID = edm_domain_id_src;

     -- relation:
     insert into EDM_RELATION
            (RELATION_ID, DOMAIN_ID, SRC_OBJECT_ID, DST_OBJECT_ID, LRS, KIND, RELTYPE_ID, SRC_VERSION_ID,
             DST_VERSION_ID, SRC_CONTEXT_PATH_ID, DST_CONTEXT_PATH_ID, SEQUENCE_FROM, SEQUENCE_TO, SUCCESSION)
     select /*+dynamic_sampling(t 0) ordered */ t.RELATION_ID_NEW, edm_domain_id_dst, r.SRC_OBJECT_ID, r.DST_OBJECT_ID, r.LRS, r.KIND, r.RELTYPE_ID,
            (select /*+dynamic_sampling(t1 0) nl_sj */ t1.VERSION_ID_NEW from TMP_EDM_VERSION t1 where t1.VERSION_ID = r.SRC_VERSION_ID) v1,
            (select /*+dynamic_sampling(t2 0) nl_sj */ t2.VERSION_ID_NEW from TMP_EDM_VERSION t2 where t2.VERSION_ID = r.DST_VERSION_ID) v2,
            r.SRC_CONTEXT_PATH_ID, r.DST_CONTEXT_PATH_ID, r.SEQUENCE_FROM, r.SEQUENCE_TO, r.SUCCESSION
       from TMP_EDM_RELATION t, EDM_RELATION r
      where r.RELATION_ID = t.RELATION_ID and r.DOMAIN_ID = edm_domain_id_src;

     -- context (part 2)
     insert into EDM_CONTEXT_PATH_DATA (SEQUENCE_FROM, SEQUENCE_TO, CONTEXT_PATH_ID, RELATION_ID, DOMAIN_ID, XMIID, PARENT_CONTEXT_PATH_ID)
     select /*+dynamic_sampling(r 0) ordered */ cp.SEQUENCE_FROM, cp.SEQUENCE_TO, cp.CONTEXT_PATH_ID, r.RELATION_ID_NEW, edm_domain_id_dst, cp.XMIID, cp.PARENT_CONTEXT_PATH_ID
       from TMP_EDM_RELATION r, EDM_CONTEXT_PATH_DATA cp
      where r.RELATION_ID = cp.RELATION_ID;

     -- attributes
     insert into EDM_CONTEXT_ATTRIBUTE_VALUE (SEQUENCE_FROM, SEQUENCE_TO, OBJECT_ID, ATTR_ID, DOMAIN_ID, ATTR_VALUE, CONTEXT_PATH_ID, ATTR_LONG_VALUE, VERSION_ID)
     select cav.SEQUENCE_FROM, cav.SEQUENCE_TO, cav.OBJECT_ID, cav.ATTR_ID, edm_domain_id_dst, ATTR_VALUE, cav.CONTEXT_PATH_ID, cav.ATTR_LONG_VALUE,
           (select /*+dynamic_sampling(t1 0) nl_sj */ t1.VERSION_ID_NEW from TMP_EDM_VERSION t1 where t1.VERSION_ID = cav.VERSION_ID) v
       from EDM_CONTEXT_ATTRIBUTE_VALUE cav
      where cav.DOMAIN_ID = edm_domain_id_src;

     -- context mappings
     insert into EDM_CONTEXT_MAPPING (MAPPED_CONTEXT_PATH_ID, CONTEXT_PATH_ID, DOMAIN_ID, SEQUENCE_NR)
     select cm.MAPPED_CONTEXT_PATH_ID, cm.CONTEXT_PATH_ID, edm_domain_id_dst, cm.SEQUENCE_NR
       from EDM_CONTEXT_MAPPING cm
      where cm.DOMAIN_ID = edm_domain_id_src;

     -- svn mappings
     insert into EDM_SVN_MAPPING (DOMAIN_ID, SEQUENCE_NR, SVN_REVISION_NUMBER)
     select edm_domain_id_dst, SEQUENCE_NR, SVN_REVISION_NUMBER from EDM_SVN_MAPPING where DOMAIN_ID = edm_domain_id_src;

     return 1;
   end f_edm_copy_model;

  -- -------------------------------------------------------------------------------------------
  -- helpers for breaking up a reuse
  -- -------------------------------------------------------------------------------------------

  procedure p_replaceInTypeRelations(vDomainId nestor_bereich.domain_id%TYPE, vCtxId edm_context_path_data.context_path_id%TYPE, vObjectId edm_object_data.object_id%TYPE,
                                     vOldVersionId edm_version_data.version_id%TYPE, vNewVersionId edm_version_data.version_id%TYPE) is
    cursor cTypedRelSource(vDomainId nestor_bereich.domain_id%TYPE, vCtxId edm_context_path_data.context_path_id%TYPE,
                           vObjectId edm_object_data.object_id%TYPE, vVersionId edm_version_data.version_id%TYPE) is
      select /*+index_asc(r (src_object_id))*/ r.rowid rel_rowid, r.*
        from edm_v_relation r
       where r.kind = 'T'
         and r.domain_id = vDomainId and r.src_object_id = vObjectId
         and nvl(r.src_version_id, '-') = nvl(vVersionId, '-')
         and r.src_context_path_id = vCtxId;
    cursor cTypedRelDest(vDomainId nestor_bereich.domain_id%TYPE, vCtxId edm_context_path_data.context_path_id%TYPE,
                         vObjectId edm_object_data.object_id%TYPE, vVersionId edm_version_data.version_id%TYPE) is
      select /*+index_asc(r (dst_object_id))*/ r.rowid rel_rowid, r.*
        from edm_v_relation r
       where r.kind = 'T'
         and r.domain_id = vDomainId and r.dst_object_id = vObjectId
         and nvl(r.dst_version_id, '-') = nvl(vVersionId, '-')
         and r.dst_context_path_id = vCtxId;
  begin
    for rRel in cTypedRelSource(vDomainId, vCtxId, vObjectId, vOldVersionId) loop
      update edm_v_relation set src_version_id = vNewVersionId
       where rowid = rRel.rel_rowid;
    end loop;
    for rRel in cTypedRelDest(vDomainId, vCtxId, vObjectId, vOldVersionId) loop
      update edm_v_relation set dst_version_id = vNewVersionId
       where rowid = rRel.rel_rowid;
    end loop;
  end p_replaceInTypeRelations;

  procedure p_replaceContextAttributes(vDomainId nestor_bereich.domain_id%TYPE, vCtxId edm_context_path_data.context_path_id%TYPE, vObjectId edm_object_data.object_id%TYPE,
                             vOldVersionId edm_version_data.version_id%TYPE, vNewVersionId edm_version_data.version_id%TYPE) is
    cursor cContextAttribute(vDomainId nestor_bereich.domain_id%TYPE, vCtxId edm_context_path_data.context_path_id%TYPE, vObjectId edm_object_data.object_id%TYPE,
                             vVersionId edm_version_data.version_id%TYPE) is
      select /*+index(ca i_edm_ctx_attribute_value_obj) */ ca.rowid ca_rowid
        from edm_v_context_attribute_value ca
       where ca.domain_id = vDomainId
         and ca.context_path_id = vCtxId
         and ca.object_id = vObjectId
         and nvl(ca.version_id, '-') = nvl(vVersionId, '-');
  begin
    /* handle context attributes - only change in existing records needed */
    for rContextAttribute in cContextAttribute(vDomainId, vCtxId, vObjectId, vOldVersionId) loop
      update edm_v_context_attribute_value set version_id = vNewVersionId where rowid = rContextAttribute.ca_rowid;
    end loop;
  end p_replaceContextAttributes;

  procedure p_fixGapInRelationSeq(vRowid urowid) is
    cursor cContexts(vRelationId edm_context_path_data.relation_id%TYPE, vFrom edm_context_path_data.sequence_from%type, vTo edm_context_path_data.sequence_to%TYPE) is
      select *
        from edm_context_path_data cpd
       where cpd.relation_id = vRelationId
         and greatest(cpd.sequence_from, vFrom) <= least(cpd.sequence_to, vTo)
       order by sequence_from, sequence_to;
    sMin            edm_relation.sequence_from%TYPE;
    sMax            edm_relation.sequence_to%TYPE;
    sCurrentFrom    edm_relation.sequence_from%TYPE;
    sCurrentTo      edm_relation.sequence_to%TYPE;
    sRelationId     edm_relation.relation_id%TYPE;
    sNewRelationId  edm_relation.relation_id%TYPE;
  begin
    select sequence_from, sequence_to, relation_id, (select nvl(min(sequence_from), -1) from edm_context_path_data where r.relation_id = relation_id and domain_id = r.domain_id) cpd_min,
           (select nvl(max(sequence_to), -1) from edm_context_path_data where r.relation_id = relation_id and domain_id = r.domain_id) cpd_max
      into sMin, sMax, sRelationId, sCurrentFrom, sCurrentTo
      from edm_relation r
     where r.rowid = vRowid;

    -- delete ? --
    if sCurrentFrom = -1 then
      delete from edm_relation where rowid = vRowid;
      return;
    end if;
    if sCurrentFrom <> sMin or sCurrentTo <> sMax then
      update edm_relation set sequence_from = sCurrentFrom, sequence_to = sCurrentTo where rowid = vRowid;
    end if;

    sCurrentFrom := sMin;
    sCurrentTo := sMin;
    for rContexts in cContexts(sRelationId, sMin, sMax) loop
      /* new to ? */
      if rContexts.sequence_from <= sCurrentTo then
        sCurrentTo := greatest(sCurrentTo, rContexts.sequence_to);
      else /* hole found! */
         -- repair --
         sNewRelationId := sys_guid();
         insert into edm_relation(sequence_from, sequence_to, relation_id, domain_id, src_object_id, dst_object_id,
                                  lrs, kind, reltype_id, src_version_id, dst_version_id, src_context_path_id, dst_context_path_id, succession)
           select sCurrentFrom, sCurrentTo, sNewRelationId, domain_id, src_object_id, dst_object_id, lrs, kind, reltype_id, src_version_id, dst_version_id, src_context_path_id, dst_context_path_id, succession
             from edm_v_relation r
            where r.rowid = vRowid;
         update edm_context_path_data
            set relation_id = sNewRelationId
          where relation_id = sRelationId
            and greatest(sequence_from, sCurrentFrom) <= least(sequence_to, sCurrentTo);
         update edm_relation set sequence_from = rContexts.sequence_from where rowid = vRowid;
         sCurrentFrom := rContexts.sequence_from;
         sCurrentTo := rContexts.sequence_to;
       end if;
     end loop;
  end p_fixGapInRelationSeq;

  procedure p_solveReuse(vDomainId nestor_bereich.domain_id%TYPE, vCtxId edm_context_path_data.context_path_id%TYPE,
                         vObjectId edm_object_data.object_id%TYPE, vXmiid edm_context_path_data.xmiid%TYPE,
                         vOldVersionId edm_version_data.version_id%TYPE, vNewVersionId edm_version_data.version_id%TYPE) is
    cursor cObjectDataToCopy(vDomainId nestor_bereich.domain_id%TYPE, vCtxId edm_context_path_data.context_path_id%TYPE, vXmiid edm_context_path_data.xmiid%TYPE,
                             vVersionId edm_version_data.version_id%TYPE) is
      select /*+ ordered use_nl(cpd r od) index(cpd (xmiid)) index(r (relation_id)) index(od (object_id)) */ od.*, greatest(cpd.sequence_from, od.sequence_from) maxFrom, least(cpd.sequence_to, od.sequence_to) minTo
        from edm_context_path_data cpd, edm_relation r, edm_object_data od
       where cpd.domain_id = vDomainId
         and cpd.xmiid = vXmiid
         and cpd.relation_id = r.relation_id
         and nvl(r.dst_version_id, '-') = nvl(vVersionId, '-')
         and r.dst_object_id = od.object_id
         and r.domain_id = od.domain_id
         and nvl(od.version_id, '-') = nvl(r.dst_version_id,'-')
         and greatest(cpd.sequence_from, od.sequence_from) <= least(cpd.sequence_to, od.sequence_to);
    cursor cUsageRelTarget(vDomainId nestor_bereich.domain_id%TYPE, vCtxId edm_context_path_data.context_path_id%TYPE, vXmiid edm_context_path_data.xmiid%TYPE, vVersionId edm_version_data.version_id%TYPE) is
      select /*+ordered use_nl(cpd r) index_asc(cpd (xmiid)) index(r (relation_id)) */ cpd.rowid cpd_rowid, r.rowid rel_rowid, r.*, (select count(1) from edm_v_context_path_data where relation_id = r.relation_id and rownum <= 2) relation_usage_count, cpd.sequence_from cpd_from, cpd.sequence_to cpd_to
        from edm_v_context_path_data cpd, edm_v_relation r
       where r.relation_id = cpd.relation_id and nvl(r.dst_version_id,'-') = nvl(vVersionId,'-') and cpd.domain_id = vDomainId and cpd.context_path_id = vCtxId and cpd.xmiid = vXmiid;
    cursor cUsageRelSource(vDomainId nestor_bereich.domain_id%TYPE, vCtxId edm_context_path_data.context_path_id%TYPE, vObjectId edm_object_data.object_id%TYPE, vVersionId edm_version_data.version_id%TYPE) is
      select /*+ordered use_hash(cpd r) index_asc(cpd (parent_context_path_id)) index_asc(r (src_object_id))*/ cpd.rowid cpd_rowid, r.rowid rel_rowid, r.*, (select count(1) from edm_v_context_path_data where relation_id = r.relation_id and rownum <= 2) relation_usage_count,
             cpd.sequence_from max_from, cpd.sequence_to min_to
        from edm_v_context_path_data cpd, edm_v_relation r
       where cpd.parent_context_path_id = vCtxId and cpd.domain_id = vDomainId
         and r.src_object_id = vObjectId
         and r.domain_id = vDomainId
         and r.kind = 'U'
         and nvl(r.src_version_id,'-') = nvl(vVersionId,'-')
         and cpd.relation_id = r.relation_id
       order by cpd.relation_id;
    fCurrentRelationId edm_relation.relation_id%TYPE;
    fNewRelationId     edm_relation.relation_id%TYPE;
  begin
    /* copy object data entries with new object and version ids from the given map. */
    for rObjectDataToCopy in cObjectDataToCopy(vDomainId, vCtxId, vXmiid,vOldVersionId) loop
      insert into edm_v_object_data(sequence_from, sequence_to, domain_id, object_id, version_id, is_root, type_id)
        values (rObjectDataToCopy.maxFrom, rObjectDataToCopy.minTo, vDomainId, vObjectId, vNewVersionId, rObjectDataToCopy.is_root, rObjectDataToCopy.type_id);
      /* copy attribute values to new object: */
      insert into edm_v_context_attribute_value (sequence_from, sequence_to, object_id, version_id,
                                                 attr_id, domain_id, attr_value, attr_long_value, file_id)
        select /*+ ordered use_nl(cpd r ca) index(cpd (xmiid)) index(r (relation_id)) index(ca (object_id)) */ greatest(ca.sequence_from, cpd.sequence_from), least(ca.sequence_to, cpd.sequence_to), vObjectId, vNewVersionId, attr_id, ca.domain_id, attr_value, attr_long_value, file_id
          from edm_v_context_path_data cpd,
               edm_v_relation r,
               edm_v_context_attribute_value ca
         where cpd.xmiid = vXmiid
           and cpd.domain_id = vDomainId
           and cpd.relation_id = r.relation_id
           and nvl(r.dst_version_id, '-') = nvl(vOldVersionId, '-')
           and cpd.domain_id = ca.domain_id
           and ca.object_id = r.dst_object_id
           and nvl(ca.version_id, '-') = nvl(r.dst_version_id, '-')
           and ca.context_path_id is null
           and greatest(ca.sequence_from, cpd.sequence_from) <= least(ca.sequence_to, cpd.sequence_to);
    end loop;
    /* modify or insert relation usage entries where the old object is a target. If the difference is the top of a reuse hierarchy, we can directly update, otherwise we need a copy. */
    for rUsageRelTarget in cUsageRelTarget(vDomainId, vCtxId, vXmiid, vOldVersionId) loop
      if rUsageRelTarget.relation_usage_count = 1 then
        update edm_v_relation
           set dst_version_id = vNewVersionId
         where rowid = rUsageRelTarget.rel_rowid;
      else
         fNewRelationId := sys_guid();
         insert into edm_v_relation(relation_id, domain_id, src_object_id, src_version_id, dst_object_id, dst_version_id, lrs, kind,
                                   reltype_id, src_context_path_id, dst_context_path_id, sequence_from, sequence_to, succession)
         values (fNewRelationId, rUsageRelTarget.domain_id, rUsageRelTarget.src_object_id, rUsageRelTarget.src_version_id,
                  vObjectId, vNewVersionId, rUsageRelTarget.lrs, rUsageRelTarget.kind,
                  rUsageRelTarget.reltype_id, rUsageRelTarget.src_context_path_id, rUsageRelTarget.dst_context_path_id,
                  rUsageRelTarget.cpd_from, rUsageRelTarget.cpd_to, rUsageRelTarget.succession);
         update edm_v_context_path_data set relation_id = fNewRelationId where rowid = rUsageRelTarget.cpd_rowid;
         /* use only if micro delta has problems with gaps in relation sequence from/to */
         /*p_fixGapInRelationSeq(rUsageRelTarget.rel_rowid); */
      end if;
    end loop;
    /* copy usage relation entries to children (versioned object, non-roots will be handled separately) and let the context_path_data entry point to them: */
    fCurrentRelationId := '';
    for rUsageRelSource in cUsageRelSource(vDomainId, vCtxId, vObjectId, vOldVersionId) loop
      if rUsageRelSource.relation_usage_count = 1 then
        update edm_v_relation
           set src_version_id = vNewVersionId
         where rowid = rUsageRelSource.rel_rowid;
      else
        fNewRelationId := sys_guid();

        insert into edm_v_relation(relation_id, domain_id, src_object_id, src_version_id, dst_object_id, dst_version_id, lrs, kind,
                                   reltype_id, src_context_path_id, dst_context_path_id, sequence_from, sequence_to, succession)
        values (fNewRelationId, rUsageRelSource.domain_id, vObjectId, vNewVersionId,
                rUsageRelSource.dst_object_id, rUsageRelSource.dst_version_id, rUsageRelSource.lrs, rUsageRelSource.kind,
                rUsageRelSource.reltype_id, rUsageRelSource.src_context_path_id, rUsageRelSource.dst_context_path_id,
                rUsageRelSource.max_from, rUsageRelSource.min_to, rUsageRelSource.succession);
        update edm_v_context_path_data set relation_id = fNewRelationId where rowid = rUsageRelSource.cpd_rowid;
      end if;
    end loop;
    /* modify associations: */
    p_replaceInTypeRelations(vDomainId, vCtxId, vObjectId, vOldVersionId, vNewVersionId);
    /* handle attributes */
    p_replaceContextAttributes(vDomainId, vCtxId , vObjectId, vOldVersionId, vNewVersionId);
    /* remove from temporary table */
    delete /*+ index(r (version_id))*/ tmp_edm_reuses r where cp1_xmiid = vXmiid and version_id = vOldVersionId;
    delete /*+ index(r (version_id, cp2_xmiid))*/ tmp_edm_reuses r where cp2_xmiid = vXmiid and version_id = vOldVersionId;
  end p_solveReuse;

  function f_createBranchName(vDomainId nestor_bereich.domain_id%TYPE, vVersionId edm_object_data.version_id%TYPE)
    return varchar2 is
    sBranchBase  edm_version_data.variant_name%TYPE;
    sBranchName  edm_version_data.variant_name%TYPE;
    sCount       number;
    type tVariantNames is table of edm_version_data.variant_name%TYPE;
    aVariantNames tVariantNames;
    type tHash is table of binary_integer index by edm_version_data.variant_name%TYPE;
    aHash tHash;
  begin
    select /*+index(vd (version_id))*/ variant_name || '@' || revision || '.'
      into sBranchBase
      from edm_version_data vd
     where domain_id = vDomainId and version_id = vVersionId and rownum <= 1;

    select /*+use_nl(vd) index(vd (version_id))*/ variant_name
      bulk collect into aVariantNames
      from edm_version_data vd
     where vd.version_id in (select /*+nl_sj ordered use_nl(v2 v) index(v2 (version_id)) index(v (el_id))*/v.version_id
                               from edm_v_version v2, edm_version v where v.el_id = v2.el_id and v2.version_id = vVersionId)
      and vd.domain_id = vDomainId and variant_name like sBranchBase||'%';

    for i in 1 .. aVariantNames.count loop
      aHash(aVariantNames(i)) := 0;
    end loop;

    sCount := 0;
    loop
      sBranchName := sBranchBase || to_char(sCount);
      sCount := sCount + 1;
      exit when not aHash.exists(sBranchName);
    end loop;

    return sBranchName;
  end f_createBranchName;

  procedure p_createNewBranch(vDomainId nestor_bereich.domain_id%TYPE, vOldVersionId edm_object_data.version_id%TYPE,
                              vNewVersionId edm_version_data.version_id%TYPE, vXmiid edm_context_path_data.xmiid%TYPE) is
    cursor cVersionEntryToCopy(vDomainId nestor_bereich.domain_id%TYPE, vVersionId edm_object_data.version_id%TYPE) is
      select /*+ ordered use_nl(cpd r vd) index(cpd (xmiid)) index(r (relation_id)) index(vd (version_id)) */ vd.*, greatest(cpd.sequence_from, vd.sequence_from) max_from, least(cpd.sequence_to, vd.sequence_to) min_to
        from edm_context_path_data cpd, edm_relation r, edm_version_data vd
       where cpd.domain_id = vDomainId
         and cpd.xmiid = vXmiid
         and cpd.relation_id = r.relation_id
         and nvl(r.dst_version_id, '-') = nvl(vVersionId, '-')
         and vd.version_id = vVersionId
         and greatest(cpd.sequence_from, vd.sequence_from) <= least(cpd.sequence_to, vd.sequence_to)
       order by vd.sequence_from asc;
    rVersionData edm_version_data%ROWTYPE;
    sNewVariantName edm_version_data.variant_name%TYPE;
    sFrom         edm_version_data.sequence_from%TYPE;
    sTo           edm_version_data.sequence_to%TYPE;
    sNewVariantId edm_version_data.variant_id%TYPE;
    sOldVariantId edm_version_data.variant_id%TYPE;
	sMetaModelVer nestor_bereich.meta_model_version%TYPE;
    sNotLatest    boolean := false;
  begin
    select variant_id into sOldVariantId from edm_version_data where version_id = vOldVersionId and rownum <= 1;
	select meta_model_version into sMetaModelVer from nestor_bereich where domain_id = vDomainId;

    sNewVariantName := f_createBranchName(vDomainId, vOldVersionId);
    /* branch id will be determined from old branch id, new branch name and meta model version*/
    sNewVariantId := lower( rawtohex(dbms_obfuscation_toolkit.md5(input=>utl_raw.cast_to_raw(sOldVariantId || '#' || sNewVariantName || '#' || sMetaModelVer))));

    /* create pk */
    insert into edm_version(version_id, el_id) select vNewVersionId, el_id from edm_version where version_id = vOldVersionId;

    for rVersionData in cVersionEntryToCopy(vDomainId, vOldVersionId) loop
      insert into edm_version_data(sequence_from, sequence_to, version_id, domain_id, variant_id, variant_name, revision, system_state, predecessor_1)
        values (rVersionData.max_from, rVersionData.min_to, vNewVersionId, vDomainId, sNewVariantId, sNewVariantName, 0, rVersionData.system_state, rVersionData.predecessor_1);
    end loop;
  end p_createNewBranch;


  -- -------------------------------------------------------------------------------------------
  -- break-up a reuse
  -- -------------------------------------------------------------------------------------------

  function f_resolveReuseAsBranch(
      vDomainId              IN      nestor_bereich.domain_id%TYPE,
      vXmiid                 IN      edm_context_path_data.xmiid%TYPE,
      vCtxId                 IN      edm_context_path_data.context_path_id%TYPE,
      vObjectId              IN      edm_object_data.object_id%TYPE,
      vVersionId             IN      edm_object_data.version_id%TYPE,
      vFrom                  IN      edm_context_path_data.sequence_from%TYPE,
      vTo                    IN      edm_context_path_data.sequence_to%TYPE,
      vMessage               IN      edm_backuprestore_log.message%TYPE,
      vOtherReuseXmiid       IN      edm_context_path_data.xmiid%TYPE,
      vOtherCtxId            IN      edm_context_path_data.context_path_id%TYPE
  ) return boolean is
    cursor cVersionObject(vDomainId nestor_bereich.domain_id%TYPE, vCtxId edm_object_data.version_id%TYPE, vFrom edm_context_path_data.sequence_from%TYPE,
                          vTo edm_context_path_data.sequence_to%TYPE) is
      select x.*
        from (select /*+ ordered use_nl(cpd r) index(cpd (context_path_id)) index(r (relation_id)) */ r.dst_object_id, cpd.xmiid, cpd.sequence_from cpd_from, cpd.sequence_to cpd_to
                from edm_v_context_path_data cpd, edm_v_relation r
               where cpd.context_path_id = vCtxId
                 and cpd.domain_id = vDomainId
                 and cpd.parent_context_path_id <> cpd.context_path_id
                and r.relation_id = cpd.relation_id
                and greatest(vFrom, cpd.sequence_from) <= least(vTo, cpd.sequence_to)
              order by cpd.sequence_from asc) x
       where rownum <= 1;
    cursor cDependentObjects(vDomainId nestor_bereich.domain_id%TYPE, vCtxId edm_object_data.version_id%TYPE, vVersionId edm_version_data.version_id%TYPE) is
      select /*+ordered use_nl(cpd r) index(cpd (parent_context_path_id)) index(r (relation_id)) */ distinct r.dst_object_id dst_object_id, cpd.xmiid
        from edm_v_context_path_data cpd, edm_v_relation r
       where cpd.domain_id = vDomainId
         and cpd.context_path_id = cpd.parent_context_path_id
         and cpd.context_path_id = vCtxId
         and cpd.relation_id = r.relation_id
         and nvl(r.dst_version_id, '-') = nvl(vVersionId, '-')
       order by r.dst_object_id;
    sNewVersionId edm_version_data.version_id%TYPE;
    sIsRoot varchar2(1);
    sCount        number;
    sObjectIdToUse edm_object_data.object_id%TYPE;
    sXmiidToUse    edm_context_path_data.xmiid%TYPE;
    sContextToUse  edm_context_path_data.context_path_id%TYPE;
    rVersionObj1   cVersionObject%ROWTYPE;
    rVersionObj2   cVersionObject%ROWTYPE;
  begin
	/* check if reuse pair exists - may be removed because of a fix prior to this call: */
	select count(1)
	  into sCount
	  from (select /*+ index(r (version_id,cp2_xmiid))*/ 1 from tmp_edm_reuses r
	         where version_id = vVersionId and cp1_xmiid = vOtherReuseXmiid and cp2_xmiid = vXmiid
	        union all
	        select /*+ index(r (version_id,cp2_xmiid))*/ 1 from tmp_edm_reuses r
	         where version_id = vVersionId and cp1_xmiid = vXmiid and cp2_xmiid = vOtherReuseXmiid);
    if sCount = 0 then
      return false;
    end if;

    insert into edm_backuprestore_log(log_date, model_name, message)
      select NESTOR_BENUTZER_KONTEXT.F_EDM_GET_UTC_SYS_DATE, model_name, vMessage
        from edm_v_domain where domain_id = vDomainId;

    /* is root? */
    select /*+index(o (object_id))*/ is_root
      into sIsRoot
      from edm_v_object_data o
     where domain_id = vDomainId and object_id = vObjectId and version_id = vVersionId and rownum <= 1;

    /* non-root: find the root to start the change with: */
    if sIsRoot = 'F' then
      open cVersionObject(vDomainId, vCtxId, vFrom, vTo);
      fetch cVersionObject into rVersionObj1;
      close cVersionObject;
      open cVersionObject(vDomainId, vOtherCtxId, vFrom, vTo);
      fetch cVersionObject into rVersionObj2;
      close cVersionObject;

      if rVersionObj2.cpd_from > rVersionObj1.cpd_from then
        sObjectIdToUse := rVersionObj2.dst_object_id;
        sXmiidToUse := rVersionObj2.xmiid;
        sContextToUse := vOtherCtxId;
      else
        sObjectIdToUse := rVersionObj1.dst_object_id;
        sXmiidToUse := rVersionObj1.xmiid;
        sContextToUse := vCtxId;
      end if;
      insert into edm_backuprestore_log(log_date, model_name, message)
        select NESTOR_BENUTZER_KONTEXT.F_EDM_GET_UTC_SYS_DATE, model_name, 'Fix version object first, xmiid: ' || sXmiidToUse
         from edm_v_domain d where d.domain_id = vDomainId;
    else
      sObjectIdToUse := vObjectId;
      sXmiidToUse := vXmiid;
      sContextToUse := vCtxId;
    end if;

    /* create branch: */
    sNewVersionId := sys_guid();
    p_createNewBranch(vDomainId, vVersionId, sNewVersionId, sXmiidToUse);

    /* branch version root: */
     p_solveReuse(vDomainId, sContextToUse, sObjectIdToUse, sXmiidToUse, vVersionId, sNewVersionId);

     /* change all dependent objects. Note: the relation to these objects are now with the new version id!: */
    for rDependentObjects in cDependentObjects(vDomainId, sContextToUse, vVersionId) loop
      insert into edm_backuprestore_log(log_date, model_name, message)
          select NESTOR_BENUTZER_KONTEXT.F_EDM_GET_UTC_SYS_DATE, model_name, 'Dependent child to fix, xmiid: ' || rDependentObjects.xmiid || ', parent xmiid: ' || sXmiidToUse || ' from model version '
           || (select min(cpd.sequence_from) from edm_v_context_path_data cpd where cpd.domain_id = vDomainId and cpd.xmiid = rDependentObjects.xmiid) || ' to model version '
           || (select max(cpd.sequence_to) from edm_v_context_path_data cpd where cpd.domain_id = vDomainId and cpd.xmiid = rDependentObjects.xmiid)
            from edm_v_domain d where d.domain_id = vDomainId;
      p_solveReuse(vDomainId, sContextToUse, rDependentObjects.dst_object_id, rDependentObjects.xmiid, vVersionId, sNewVersionId);
    end loop;

    return true;
   end f_resolveReuseAsBranch;

   procedure p_markCheckRelevantReuses is
   begin
     update /*+full(x1)*/ tmp_edm_reuses x1
        set to_check = 'T'
      where to_check = 'F'
        and not exists (select /*+nl_aj ordered use_nl(x2 x3) index(x2 (version_id,cp2_xmiid)) index(x3 (version_id,cp2_xmiid))*/ null from tmp_edm_reuses x2, tmp_edm_reuses x3
      where x2.cp2_xmiid = x1.cp1_xmiid and x2.object_id = x1.object_id and x2.version_id = x1.version_id
        and x1.sequence_from >= x2.sequence_from and x1.sequence_to <= x2.sequence_to
        and x3.cp2_xmiid = x1.cp2_xmiid and x3.object_id = x1.object_id and x3.version_id = x1.version_id and x3.cp1_xmiid = x2.cp1_xmiid
        and x1.sequence_from >= greatest(x2.sequence_from,x3.sequence_from) and x1.sequence_to <= least(x2.sequence_to,x3.sequence_to));
   end p_markCheckRelevantReuses;

   procedure p_checkinVersion(
      vDomainId       IN nestor_bereich.domain_id%TYPE,
      vTargetRowid    IN rowid,
      vCheckedInSince IN edm_version_data.sequence_from%TYPE,
      vMessage        IN edm_backuprestore_log.message%TYPE
   ) is
     cursor cNextCheckIn(vDomain varchar2, vVersionId varchar2, vStartSequence number) is
       select /*+index(vd (version_id))*/ vd.rowid vd_rowid, vd.sequence_to
         from edm_version_data vd
        where vd.domain_id = vDomain and vd.version_id = vVersionId and vd.system_state = 'I' and vd.sequence_from = vStartSequence and rownum <= 1 ;
     rTargetRow     edm_version_data%rowtype;
     sNewSequenceTo edm_version_data.sequence_to%TYPE;
   begin
     select * into rTargetRow from edm_version_data where rowid = vTargetRowid;

     if rTargetRow.sequence_from >= vCheckedInSince then
       /* target version created after checkin of relation source: update entry. */
       update edm_version_data set system_state = 'I' where rowid = vTargetRowid;
       sNewSequenceTo := rTargetRow.sequence_to;
       /* existing check in: change entry and remove (now duplicate) check in: */
       for rNextCheckIn in cNextCheckIn(vDomainId, rTargetRow.version_id, rTargetRow.sequence_to + 1) loop
         sNewSequenceTo := rNextCheckIn.sequence_to;
         delete edm_version_data where rowid = rNextCheckIn.vd_rowid;
         update edm_version_data set sequence_to = sNewSequenceTo where rowid = vTargetRowid;
       end loop;
     else
       update edm_version_data set sequence_to = vCheckedInSince - 1 where rowid = vTargetRowid;
       sNewSequenceTo := rTargetRow.sequence_to;
       for rNextCheckIn in cNextCheckIn(vDomainId, rTargetRow.version_id, rTargetRow.sequence_to + 1) loop
         sNewSequenceTo := rNextCheckIn.sequence_to;
         delete edm_version_data where rowid = rNextCheckIn.vd_rowid;
       end loop;
       insert into edm_version_data(sequence_from, sequence_to, version_id, variant_id, variant_name, domain_id, revision, system_state, predecessor_1)
       values (vCheckedInSince, sNewSequenceTo, rTargetRow.version_id, rTargetRow.variant_id, rTargetRow.variant_name, vDomainId, rTargetRow.revision, 'I', rTargetRow.predecessor_1);
     end if;
     /* check in any subsequent occurrences */
     update /*+index(vd (version_id))*/ edm_version_data vd set system_state = 'I' where version_id = rTargetRow.version_id and domain_id = vDomainId and sequence_from > sNewSequenceTo;
     insert into edm_backuprestore_log(log_date, model_name, message)
       select NESTOR_BENUTZER_KONTEXT.F_EDM_GET_UTC_SYS_DATE, model_name, vMessage from nestor_bereich where domain_id = vDomainId;
   end p_checkinVersion;

END edm_admin_fct_2;
/
