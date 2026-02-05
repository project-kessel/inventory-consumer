--
-- PostgreSQL database dump
--

\restrict 91gEmHJc7icrkLJUKUh3MElaSBwipOLoRNjc9lvxn6aHVlRJ7YC6Uab8LBy4yV2

-- Dumped from database version 16.10
-- Dumped by pg_dump version 17.7

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: hbi; Type: SCHEMA; Schema: -; Owner: Vf8S7GalvGVmaHGx
--

CREATE SCHEMA hbi;


ALTER SCHEMA hbi OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: populate_system_profiles_dynamic_insights_id(); Type: FUNCTION; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE FUNCTION hbi.populate_system_profiles_dynamic_insights_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        DECLARE
            v_host_insights_id UUID;
        BEGIN
            SELECT insights_id INTO v_host_insights_id
            FROM hbi.hosts
            WHERE org_id = NEW.org_id AND id = NEW.host_id;

            IF v_host_insights_id IS DISTINCT FROM NEW.insights_id THEN
                UPDATE hbi.system_profiles_dynamic
                SET insights_id = v_host_insights_id
                WHERE org_id = NEW.org_id AND host_id = NEW.host_id;
            END IF;

            RETURN NULL;
        END;
        $$;


ALTER FUNCTION hbi.populate_system_profiles_dynamic_insights_id() OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: populate_system_profiles_static_insights_id(); Type: FUNCTION; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE FUNCTION hbi.populate_system_profiles_static_insights_id() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        DECLARE
            v_host_insights_id UUID;
        BEGIN
            SELECT insights_id INTO v_host_insights_id
            FROM hbi.hosts
            WHERE org_id = NEW.org_id AND id = NEW.host_id;

            IF v_host_insights_id IS DISTINCT FROM NEW.insights_id THEN
                UPDATE hbi.system_profiles_static
                SET insights_id = v_host_insights_id
                WHERE org_id = NEW.org_id AND host_id = NEW.host_id;
            END IF;

            RETURN NULL;
        END;
        $$;


ALTER FUNCTION hbi.populate_system_profiles_static_insights_id() OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: sync_insights_id_to_system_profiles(); Type: FUNCTION; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE FUNCTION hbi.sync_insights_id_to_system_profiles() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
        BEGIN
            IF (TG_OP = 'UPDATE' AND NEW.insights_id IS DISTINCT FROM OLD.insights_id) THEN
                UPDATE hbi.system_profiles_static
                SET insights_id = NEW.insights_id
                WHERE org_id = NEW.org_id AND host_id = NEW.id;

                UPDATE hbi.system_profiles_dynamic
                SET insights_id = NEW.insights_id
                WHERE org_id = NEW.org_id AND host_id = NEW.id;
            END IF;

            RETURN NULL;
        END;
        $$;


ALTER FUNCTION hbi.sync_insights_id_to_system_profiles() OWNER TO "Vf8S7GalvGVmaHGx";

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alembic_version; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.alembic_version (
    version_num character varying(32) NOT NULL
);


ALTER TABLE hbi.alembic_version OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: debezium_signal; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.debezium_signal (
    id character varying(50) NOT NULL,
    type character varying(32) NOT NULL,
    data character varying(2048)
);


ALTER TABLE hbi.debezium_signal OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: groups; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.groups (
    id uuid NOT NULL,
    org_id character varying(36) NOT NULL,
    account character varying(10),
    name character varying(255) NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    ungrouped boolean DEFAULT false NOT NULL
);


ALTER TABLE hbi.groups OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hbi_metadata; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hbi_metadata (
    name character varying NOT NULL,
    type character varying NOT NULL,
    last_succeeded timestamp with time zone NOT NULL
);


ALTER TABLE hbi.hbi_metadata OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts (
    org_id character varying(36) NOT NULL,
    id uuid NOT NULL,
    account character varying(10),
    display_name character varying(200),
    ansible_host character varying(255),
    created_on timestamp with time zone,
    modified_on timestamp with time zone,
    facts jsonb,
    tags jsonb,
    tags_alt jsonb,
    system_profile_facts jsonb,
    groups jsonb NOT NULL,
    last_check_in timestamp with time zone,
    stale_timestamp timestamp with time zone NOT NULL,
    deletion_timestamp timestamp with time zone,
    stale_warning_timestamp timestamp with time zone,
    reporter character varying(255) NOT NULL,
    per_reporter_staleness jsonb DEFAULT '{}'::jsonb NOT NULL,
    canonical_facts_version integer,
    is_virtual boolean,
    insights_id uuid DEFAULT '00000000-0000-0000-0000-000000000000'::uuid NOT NULL,
    subscription_manager_id character varying(36),
    satellite_id character varying(255),
    fqdn character varying(255),
    bios_uuid character varying(36),
    ip_addresses jsonb,
    mac_addresses jsonb,
    provider_id character varying(500),
    provider_type character varying(50),
    display_name_reporter character varying(255),
    openshift_cluster_id uuid,
    host_type character varying(12)
)
PARTITION BY HASH (org_id);


ALTER TABLE hbi.hosts OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_advisor; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_advisor (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    recommendations integer,
    incidents integer
)
PARTITION BY HASH (org_id);


ALTER TABLE hbi.hosts_app_data_advisor OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_advisor_p0; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_advisor_p0 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    recommendations integer,
    incidents integer
);


ALTER TABLE hbi.hosts_app_data_advisor_p0 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_advisor_p1; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_advisor_p1 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    recommendations integer,
    incidents integer
);


ALTER TABLE hbi.hosts_app_data_advisor_p1 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_compliance; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_compliance (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    policies integer,
    last_scan timestamp with time zone
)
PARTITION BY HASH (org_id);


ALTER TABLE hbi.hosts_app_data_compliance OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_compliance_p0; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_compliance_p0 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    policies integer,
    last_scan timestamp with time zone
);


ALTER TABLE hbi.hosts_app_data_compliance_p0 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_compliance_p1; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_compliance_p1 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    policies integer,
    last_scan timestamp with time zone
);


ALTER TABLE hbi.hosts_app_data_compliance_p1 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_image_builder; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_image_builder (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    image_name character varying(255),
    image_status character varying(50)
)
PARTITION BY HASH (org_id);


ALTER TABLE hbi.hosts_app_data_image_builder OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_image_builder_p0; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_image_builder_p0 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    image_name character varying(255),
    image_status character varying(50)
);


ALTER TABLE hbi.hosts_app_data_image_builder_p0 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_image_builder_p1; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_image_builder_p1 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    image_name character varying(255),
    image_status character varying(50)
);


ALTER TABLE hbi.hosts_app_data_image_builder_p1 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_malware; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_malware (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    last_status character varying(50),
    last_matches integer,
    last_scan timestamp with time zone
)
PARTITION BY HASH (org_id);


ALTER TABLE hbi.hosts_app_data_malware OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_malware_p0; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_malware_p0 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    last_status character varying(50),
    last_matches integer,
    last_scan timestamp with time zone
);


ALTER TABLE hbi.hosts_app_data_malware_p0 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_malware_p1; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_malware_p1 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    last_status character varying(50),
    last_matches integer,
    last_scan timestamp with time zone
);


ALTER TABLE hbi.hosts_app_data_malware_p1 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_patch; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_patch (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    advisories_rhsa_applicable integer,
    advisories_rhba_applicable integer,
    advisories_rhea_applicable integer,
    advisories_other_applicable integer,
    advisories_rhsa_installable integer,
    advisories_rhba_installable integer,
    advisories_rhea_installable integer,
    advisories_other_installable integer,
    packages_applicable integer,
    packages_installable integer,
    packages_installed integer,
    template_name character varying(255),
    template_uuid uuid
)
PARTITION BY HASH (org_id);


ALTER TABLE hbi.hosts_app_data_patch OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_patch_p0; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_patch_p0 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    advisories_rhsa_applicable integer,
    advisories_rhba_applicable integer,
    advisories_rhea_applicable integer,
    advisories_other_applicable integer,
    advisories_rhsa_installable integer,
    advisories_rhba_installable integer,
    advisories_rhea_installable integer,
    advisories_other_installable integer,
    packages_applicable integer,
    packages_installable integer,
    packages_installed integer,
    template_name character varying(255),
    template_uuid uuid
);


ALTER TABLE hbi.hosts_app_data_patch_p0 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_patch_p1; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_patch_p1 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    advisories_rhsa_applicable integer,
    advisories_rhba_applicable integer,
    advisories_rhea_applicable integer,
    advisories_other_applicable integer,
    advisories_rhsa_installable integer,
    advisories_rhba_installable integer,
    advisories_rhea_installable integer,
    advisories_other_installable integer,
    packages_applicable integer,
    packages_installable integer,
    packages_installed integer,
    template_name character varying(255),
    template_uuid uuid
);


ALTER TABLE hbi.hosts_app_data_patch_p1 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_remediations; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_remediations (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    remediations_plans integer
)
PARTITION BY HASH (org_id);


ALTER TABLE hbi.hosts_app_data_remediations OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_remediations_p0; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_remediations_p0 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    remediations_plans integer
);


ALTER TABLE hbi.hosts_app_data_remediations_p0 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_remediations_p1; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_remediations_p1 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    remediations_plans integer
);


ALTER TABLE hbi.hosts_app_data_remediations_p1 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_vulnerability; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_vulnerability (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    total_cves integer,
    critical_cves integer,
    high_severity_cves integer,
    cves_with_security_rules integer,
    cves_with_known_exploits integer
)
PARTITION BY HASH (org_id);


ALTER TABLE hbi.hosts_app_data_vulnerability OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_vulnerability_p0; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_vulnerability_p0 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    total_cves integer,
    critical_cves integer,
    high_severity_cves integer,
    cves_with_security_rules integer,
    cves_with_known_exploits integer
);


ALTER TABLE hbi.hosts_app_data_vulnerability_p0 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_vulnerability_p1; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_app_data_vulnerability_p1 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    last_updated timestamp with time zone NOT NULL,
    total_cves integer,
    critical_cves integer,
    high_severity_cves integer,
    cves_with_security_rules integer,
    cves_with_known_exploits integer
);


ALTER TABLE hbi.hosts_app_data_vulnerability_p1 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_groups; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_groups (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    group_id uuid NOT NULL
)
PARTITION BY HASH (org_id);


ALTER TABLE hbi.hosts_groups OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_groups_old; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_groups_old (
    group_id uuid NOT NULL,
    host_id uuid NOT NULL
);


ALTER TABLE hbi.hosts_groups_old OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_groups_p0; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_groups_p0 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    group_id uuid NOT NULL
);


ALTER TABLE hbi.hosts_groups_p0 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_groups_p1; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_groups_p1 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    group_id uuid NOT NULL
);


ALTER TABLE hbi.hosts_groups_p1 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_old; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_old (
    id uuid NOT NULL,
    account character varying(10),
    display_name character varying(200),
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL,
    facts jsonb,
    tags jsonb,
    canonical_facts jsonb NOT NULL,
    system_profile_facts jsonb,
    ansible_host character varying(255),
    stale_timestamp timestamp with time zone NOT NULL,
    reporter character varying(255) NOT NULL,
    per_reporter_staleness jsonb DEFAULT '{}'::jsonb NOT NULL,
    org_id character varying(36) NOT NULL,
    groups jsonb NOT NULL,
    tags_alt jsonb,
    last_check_in timestamp with time zone,
    stale_warning_timestamp timestamp with time zone,
    deletion_timestamp timestamp with time zone
);


ALTER TABLE hbi.hosts_old OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_p0; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_p0 (
    org_id character varying(36) NOT NULL,
    id uuid NOT NULL,
    account character varying(10),
    display_name character varying(200),
    ansible_host character varying(255),
    created_on timestamp with time zone,
    modified_on timestamp with time zone,
    facts jsonb,
    tags jsonb,
    tags_alt jsonb,
    system_profile_facts jsonb,
    groups jsonb NOT NULL,
    last_check_in timestamp with time zone,
    stale_timestamp timestamp with time zone NOT NULL,
    deletion_timestamp timestamp with time zone,
    stale_warning_timestamp timestamp with time zone,
    reporter character varying(255) NOT NULL,
    per_reporter_staleness jsonb DEFAULT '{}'::jsonb NOT NULL,
    canonical_facts_version integer,
    is_virtual boolean,
    insights_id uuid DEFAULT '00000000-0000-0000-0000-000000000000'::uuid NOT NULL,
    subscription_manager_id character varying(36),
    satellite_id character varying(255),
    fqdn character varying(255),
    bios_uuid character varying(36),
    ip_addresses jsonb,
    mac_addresses jsonb,
    provider_id character varying(500),
    provider_type character varying(50),
    display_name_reporter character varying(255),
    openshift_cluster_id uuid,
    host_type character varying(12)
);


ALTER TABLE hbi.hosts_p0 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_p1; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.hosts_p1 (
    org_id character varying(36) NOT NULL,
    id uuid NOT NULL,
    account character varying(10),
    display_name character varying(200),
    ansible_host character varying(255),
    created_on timestamp with time zone,
    modified_on timestamp with time zone,
    facts jsonb,
    tags jsonb,
    tags_alt jsonb,
    system_profile_facts jsonb,
    groups jsonb NOT NULL,
    last_check_in timestamp with time zone,
    stale_timestamp timestamp with time zone NOT NULL,
    deletion_timestamp timestamp with time zone,
    stale_warning_timestamp timestamp with time zone,
    reporter character varying(255) NOT NULL,
    per_reporter_staleness jsonb DEFAULT '{}'::jsonb NOT NULL,
    canonical_facts_version integer,
    is_virtual boolean,
    insights_id uuid DEFAULT '00000000-0000-0000-0000-000000000000'::uuid NOT NULL,
    subscription_manager_id character varying(36),
    satellite_id character varying(255),
    fqdn character varying(255),
    bios_uuid character varying(36),
    ip_addresses jsonb,
    mac_addresses jsonb,
    provider_id character varying(500),
    provider_type character varying(50),
    display_name_reporter character varying(255),
    openshift_cluster_id uuid,
    host_type character varying(12)
);


ALTER TABLE hbi.hosts_p1 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: outbox; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.outbox (
    id uuid NOT NULL,
    aggregatetype character varying(255) NOT NULL,
    aggregateid uuid NOT NULL,
    operation character varying(255) NOT NULL,
    version character varying(50) NOT NULL,
    payload jsonb NOT NULL
);


ALTER TABLE hbi.outbox OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: staleness; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.staleness (
    id uuid NOT NULL,
    org_id character varying(36) NOT NULL,
    conventional_time_to_stale integer NOT NULL,
    conventional_time_to_stale_warning integer NOT NULL,
    conventional_time_to_delete integer NOT NULL,
    created_on timestamp with time zone NOT NULL,
    modified_on timestamp with time zone NOT NULL
);


ALTER TABLE hbi.staleness OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: system_profiles_dynamic; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.system_profiles_dynamic (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    insights_id uuid DEFAULT '00000000-0000-0000-0000-000000000000'::uuid NOT NULL,
    captured_date timestamp with time zone,
    running_processes character varying[],
    last_boot_time timestamp with time zone,
    installed_packages character varying[],
    network_interfaces jsonb,
    installed_products jsonb,
    cpu_flags character varying[],
    insights_egg_version character varying(50),
    kernel_modules character varying[],
    system_memory_bytes bigint,
    systemd jsonb,
    workloads jsonb
)
PARTITION BY HASH (org_id);


ALTER TABLE hbi.system_profiles_dynamic OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: system_profiles_dynamic_p0; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.system_profiles_dynamic_p0 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    insights_id uuid DEFAULT '00000000-0000-0000-0000-000000000000'::uuid NOT NULL,
    captured_date timestamp with time zone,
    running_processes character varying[],
    last_boot_time timestamp with time zone,
    installed_packages character varying[],
    network_interfaces jsonb,
    installed_products jsonb,
    cpu_flags character varying[],
    insights_egg_version character varying(50),
    kernel_modules character varying[],
    system_memory_bytes bigint,
    systemd jsonb,
    workloads jsonb
);


ALTER TABLE hbi.system_profiles_dynamic_p0 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: system_profiles_dynamic_p1; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.system_profiles_dynamic_p1 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    insights_id uuid DEFAULT '00000000-0000-0000-0000-000000000000'::uuid NOT NULL,
    captured_date timestamp with time zone,
    running_processes character varying[],
    last_boot_time timestamp with time zone,
    installed_packages character varying[],
    network_interfaces jsonb,
    installed_products jsonb,
    cpu_flags character varying[],
    insights_egg_version character varying(50),
    kernel_modules character varying[],
    system_memory_bytes bigint,
    systemd jsonb,
    workloads jsonb
);


ALTER TABLE hbi.system_profiles_dynamic_p1 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: system_profiles_static; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.system_profiles_static (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    insights_id uuid DEFAULT '00000000-0000-0000-0000-000000000000'::uuid NOT NULL,
    arch character varying(50),
    basearch character varying(50),
    bios_release_date character varying(50),
    bios_vendor character varying(100),
    bios_version character varying(100),
    bootc_status jsonb,
    cloud_provider character varying(100),
    conversions jsonb,
    cores_per_socket integer,
    cpu_model character varying(100),
    disk_devices jsonb[],
    dnf_modules jsonb[],
    enabled_services character varying(512)[],
    gpg_pubkeys character varying(512)[],
    greenboot_fallback_detected boolean,
    greenboot_status character varying(5),
    host_type character varying(12),
    image_builder jsonb,
    infrastructure_type character varying(100),
    infrastructure_vendor character varying(100),
    insights_client_version character varying(50),
    installed_packages_delta character varying(512)[],
    installed_services character varying(512)[],
    is_marketplace boolean,
    katello_agent_running boolean,
    number_of_cpus integer,
    number_of_sockets integer,
    operating_system jsonb,
    os_kernel_version character varying(20),
    os_release character varying(100),
    owner_id uuid,
    public_dns character varying(100)[],
    public_ipv4_addresses character varying(15)[],
    releasever character varying(100),
    rhc_client_id uuid,
    rhc_config_state uuid,
    rhsm jsonb,
    rpm_ostree_deployments jsonb[],
    satellite_managed boolean,
    selinux_config_file character varying(128),
    selinux_current_mode character varying(10),
    subscription_auto_attach character varying(100),
    subscription_status character varying(100),
    system_purpose jsonb,
    system_update_method character varying(10),
    third_party_services jsonb,
    threads_per_core integer,
    tuned_profile character varying(256),
    virtual_host_uuid uuid,
    yum_repos jsonb[],
    CONSTRAINT cores_per_socket_range_check CHECK (((cores_per_socket >= 0) AND (cores_per_socket <= 2147483647))),
    CONSTRAINT number_of_cpus_range_check CHECK (((number_of_cpus >= 0) AND (number_of_cpus <= 2147483647))),
    CONSTRAINT number_of_sockets_range_check CHECK (((number_of_sockets >= 0) AND (number_of_sockets <= 2147483647))),
    CONSTRAINT threads_per_core_range_check CHECK (((threads_per_core >= 0) AND (threads_per_core <= 2147483647)))
)
PARTITION BY HASH (org_id);


ALTER TABLE hbi.system_profiles_static OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: system_profiles_static_p0; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.system_profiles_static_p0 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    insights_id uuid DEFAULT '00000000-0000-0000-0000-000000000000'::uuid NOT NULL,
    arch character varying(50),
    basearch character varying(50),
    bios_release_date character varying(50),
    bios_vendor character varying(100),
    bios_version character varying(100),
    bootc_status jsonb,
    cloud_provider character varying(100),
    conversions jsonb,
    cores_per_socket integer,
    cpu_model character varying(100),
    disk_devices jsonb[],
    dnf_modules jsonb[],
    enabled_services character varying(512)[],
    gpg_pubkeys character varying(512)[],
    greenboot_fallback_detected boolean,
    greenboot_status character varying(5),
    host_type character varying(12),
    image_builder jsonb,
    infrastructure_type character varying(100),
    infrastructure_vendor character varying(100),
    insights_client_version character varying(50),
    installed_packages_delta character varying(512)[],
    installed_services character varying(512)[],
    is_marketplace boolean,
    katello_agent_running boolean,
    number_of_cpus integer,
    number_of_sockets integer,
    operating_system jsonb,
    os_kernel_version character varying(20),
    os_release character varying(100),
    owner_id uuid,
    public_dns character varying(100)[],
    public_ipv4_addresses character varying(15)[],
    releasever character varying(100),
    rhc_client_id uuid,
    rhc_config_state uuid,
    rhsm jsonb,
    rpm_ostree_deployments jsonb[],
    satellite_managed boolean,
    selinux_config_file character varying(128),
    selinux_current_mode character varying(10),
    subscription_auto_attach character varying(100),
    subscription_status character varying(100),
    system_purpose jsonb,
    system_update_method character varying(10),
    third_party_services jsonb,
    threads_per_core integer,
    tuned_profile character varying(256),
    virtual_host_uuid uuid,
    yum_repos jsonb[],
    CONSTRAINT cores_per_socket_range_check CHECK (((cores_per_socket >= 0) AND (cores_per_socket <= 2147483647))),
    CONSTRAINT number_of_cpus_range_check CHECK (((number_of_cpus >= 0) AND (number_of_cpus <= 2147483647))),
    CONSTRAINT number_of_sockets_range_check CHECK (((number_of_sockets >= 0) AND (number_of_sockets <= 2147483647))),
    CONSTRAINT threads_per_core_range_check CHECK (((threads_per_core >= 0) AND (threads_per_core <= 2147483647)))
);


ALTER TABLE hbi.system_profiles_static_p0 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: system_profiles_static_p1; Type: TABLE; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TABLE hbi.system_profiles_static_p1 (
    org_id character varying(36) NOT NULL,
    host_id uuid NOT NULL,
    insights_id uuid DEFAULT '00000000-0000-0000-0000-000000000000'::uuid NOT NULL,
    arch character varying(50),
    basearch character varying(50),
    bios_release_date character varying(50),
    bios_vendor character varying(100),
    bios_version character varying(100),
    bootc_status jsonb,
    cloud_provider character varying(100),
    conversions jsonb,
    cores_per_socket integer,
    cpu_model character varying(100),
    disk_devices jsonb[],
    dnf_modules jsonb[],
    enabled_services character varying(512)[],
    gpg_pubkeys character varying(512)[],
    greenboot_fallback_detected boolean,
    greenboot_status character varying(5),
    host_type character varying(12),
    image_builder jsonb,
    infrastructure_type character varying(100),
    infrastructure_vendor character varying(100),
    insights_client_version character varying(50),
    installed_packages_delta character varying(512)[],
    installed_services character varying(512)[],
    is_marketplace boolean,
    katello_agent_running boolean,
    number_of_cpus integer,
    number_of_sockets integer,
    operating_system jsonb,
    os_kernel_version character varying(20),
    os_release character varying(100),
    owner_id uuid,
    public_dns character varying(100)[],
    public_ipv4_addresses character varying(15)[],
    releasever character varying(100),
    rhc_client_id uuid,
    rhc_config_state uuid,
    rhsm jsonb,
    rpm_ostree_deployments jsonb[],
    satellite_managed boolean,
    selinux_config_file character varying(128),
    selinux_current_mode character varying(10),
    subscription_auto_attach character varying(100),
    subscription_status character varying(100),
    system_purpose jsonb,
    system_update_method character varying(10),
    third_party_services jsonb,
    threads_per_core integer,
    tuned_profile character varying(256),
    virtual_host_uuid uuid,
    yum_repos jsonb[],
    CONSTRAINT cores_per_socket_range_check CHECK (((cores_per_socket >= 0) AND (cores_per_socket <= 2147483647))),
    CONSTRAINT number_of_cpus_range_check CHECK (((number_of_cpus >= 0) AND (number_of_cpus <= 2147483647))),
    CONSTRAINT number_of_sockets_range_check CHECK (((number_of_sockets >= 0) AND (number_of_sockets <= 2147483647))),
    CONSTRAINT threads_per_core_range_check CHECK (((threads_per_core >= 0) AND (threads_per_core <= 2147483647)))
);


ALTER TABLE hbi.system_profiles_static_p1 OWNER TO "Vf8S7GalvGVmaHGx";

--
-- Name: hosts_app_data_advisor_p0; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_advisor ATTACH PARTITION hbi.hosts_app_data_advisor_p0 FOR VALUES WITH (modulus 2, remainder 0);


--
-- Name: hosts_app_data_advisor_p1; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_advisor ATTACH PARTITION hbi.hosts_app_data_advisor_p1 FOR VALUES WITH (modulus 2, remainder 1);


--
-- Name: hosts_app_data_compliance_p0; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_compliance ATTACH PARTITION hbi.hosts_app_data_compliance_p0 FOR VALUES WITH (modulus 2, remainder 0);


--
-- Name: hosts_app_data_compliance_p1; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_compliance ATTACH PARTITION hbi.hosts_app_data_compliance_p1 FOR VALUES WITH (modulus 2, remainder 1);


--
-- Name: hosts_app_data_image_builder_p0; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_image_builder ATTACH PARTITION hbi.hosts_app_data_image_builder_p0 FOR VALUES WITH (modulus 2, remainder 0);


--
-- Name: hosts_app_data_image_builder_p1; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_image_builder ATTACH PARTITION hbi.hosts_app_data_image_builder_p1 FOR VALUES WITH (modulus 2, remainder 1);


--
-- Name: hosts_app_data_malware_p0; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_malware ATTACH PARTITION hbi.hosts_app_data_malware_p0 FOR VALUES WITH (modulus 2, remainder 0);


--
-- Name: hosts_app_data_malware_p1; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_malware ATTACH PARTITION hbi.hosts_app_data_malware_p1 FOR VALUES WITH (modulus 2, remainder 1);


--
-- Name: hosts_app_data_patch_p0; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_patch ATTACH PARTITION hbi.hosts_app_data_patch_p0 FOR VALUES WITH (modulus 2, remainder 0);


--
-- Name: hosts_app_data_patch_p1; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_patch ATTACH PARTITION hbi.hosts_app_data_patch_p1 FOR VALUES WITH (modulus 2, remainder 1);


--
-- Name: hosts_app_data_remediations_p0; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_remediations ATTACH PARTITION hbi.hosts_app_data_remediations_p0 FOR VALUES WITH (modulus 2, remainder 0);


--
-- Name: hosts_app_data_remediations_p1; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_remediations ATTACH PARTITION hbi.hosts_app_data_remediations_p1 FOR VALUES WITH (modulus 2, remainder 1);


--
-- Name: hosts_app_data_vulnerability_p0; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_vulnerability ATTACH PARTITION hbi.hosts_app_data_vulnerability_p0 FOR VALUES WITH (modulus 2, remainder 0);


--
-- Name: hosts_app_data_vulnerability_p1; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_vulnerability ATTACH PARTITION hbi.hosts_app_data_vulnerability_p1 FOR VALUES WITH (modulus 2, remainder 1);


--
-- Name: hosts_groups_p0; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_groups ATTACH PARTITION hbi.hosts_groups_p0 FOR VALUES WITH (modulus 2, remainder 0);


--
-- Name: hosts_groups_p1; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_groups ATTACH PARTITION hbi.hosts_groups_p1 FOR VALUES WITH (modulus 2, remainder 1);


--
-- Name: hosts_p0; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts ATTACH PARTITION hbi.hosts_p0 FOR VALUES WITH (modulus 2, remainder 0);


--
-- Name: hosts_p1; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts ATTACH PARTITION hbi.hosts_p1 FOR VALUES WITH (modulus 2, remainder 1);


--
-- Name: system_profiles_dynamic_p0; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.system_profiles_dynamic ATTACH PARTITION hbi.system_profiles_dynamic_p0 FOR VALUES WITH (modulus 2, remainder 0);


--
-- Name: system_profiles_dynamic_p1; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.system_profiles_dynamic ATTACH PARTITION hbi.system_profiles_dynamic_p1 FOR VALUES WITH (modulus 2, remainder 1);


--
-- Name: system_profiles_static_p0; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.system_profiles_static ATTACH PARTITION hbi.system_profiles_static_p0 FOR VALUES WITH (modulus 2, remainder 0);


--
-- Name: system_profiles_static_p1; Type: TABLE ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.system_profiles_static ATTACH PARTITION hbi.system_profiles_static_p1 FOR VALUES WITH (modulus 2, remainder 1);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: debezium_signal debezium_signal_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.debezium_signal
    ADD CONSTRAINT debezium_signal_pkey PRIMARY KEY (id);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);

ALTER TABLE ONLY hbi.groups REPLICA IDENTITY USING INDEX groups_pkey;


--
-- Name: hbi_metadata hbi_metadata_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hbi_metadata
    ADD CONSTRAINT hbi_metadata_pkey PRIMARY KEY (name, type);


--
-- Name: hosts_app_data_advisor pk_hosts_app_data_advisor; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_advisor
    ADD CONSTRAINT pk_hosts_app_data_advisor PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_advisor_p0 hosts_app_data_advisor_p0_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_advisor_p0
    ADD CONSTRAINT hosts_app_data_advisor_p0_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_advisor_p1 hosts_app_data_advisor_p1_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_advisor_p1
    ADD CONSTRAINT hosts_app_data_advisor_p1_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_compliance pk_hosts_app_data_compliance; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_compliance
    ADD CONSTRAINT pk_hosts_app_data_compliance PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_compliance_p0 hosts_app_data_compliance_p0_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_compliance_p0
    ADD CONSTRAINT hosts_app_data_compliance_p0_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_compliance_p1 hosts_app_data_compliance_p1_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_compliance_p1
    ADD CONSTRAINT hosts_app_data_compliance_p1_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_image_builder pk_hosts_app_data_image_builder; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_image_builder
    ADD CONSTRAINT pk_hosts_app_data_image_builder PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_image_builder_p0 hosts_app_data_image_builder_p0_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_image_builder_p0
    ADD CONSTRAINT hosts_app_data_image_builder_p0_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_image_builder_p1 hosts_app_data_image_builder_p1_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_image_builder_p1
    ADD CONSTRAINT hosts_app_data_image_builder_p1_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_malware pk_hosts_app_data_malware; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_malware
    ADD CONSTRAINT pk_hosts_app_data_malware PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_malware_p0 hosts_app_data_malware_p0_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_malware_p0
    ADD CONSTRAINT hosts_app_data_malware_p0_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_malware_p1 hosts_app_data_malware_p1_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_malware_p1
    ADD CONSTRAINT hosts_app_data_malware_p1_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_patch pk_hosts_app_data_patch; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_patch
    ADD CONSTRAINT pk_hosts_app_data_patch PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_patch_p0 hosts_app_data_patch_p0_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_patch_p0
    ADD CONSTRAINT hosts_app_data_patch_p0_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_patch_p1 hosts_app_data_patch_p1_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_patch_p1
    ADD CONSTRAINT hosts_app_data_patch_p1_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_remediations pk_hosts_app_data_remediations; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_remediations
    ADD CONSTRAINT pk_hosts_app_data_remediations PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_remediations_p0 hosts_app_data_remediations_p0_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_remediations_p0
    ADD CONSTRAINT hosts_app_data_remediations_p0_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_remediations_p1 hosts_app_data_remediations_p1_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_remediations_p1
    ADD CONSTRAINT hosts_app_data_remediations_p1_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_vulnerability pk_hosts_app_data_vulnerability; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_vulnerability
    ADD CONSTRAINT pk_hosts_app_data_vulnerability PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_vulnerability_p0 hosts_app_data_vulnerability_p0_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_vulnerability_p0
    ADD CONSTRAINT hosts_app_data_vulnerability_p0_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_app_data_vulnerability_p1 hosts_app_data_vulnerability_p1_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_app_data_vulnerability_p1
    ADD CONSTRAINT hosts_app_data_vulnerability_p1_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: hosts_groups_old hosts_groups_old_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_groups_old
    ADD CONSTRAINT hosts_groups_old_pkey PRIMARY KEY (group_id, host_id);

ALTER TABLE ONLY hbi.hosts_groups_old REPLICA IDENTITY USING INDEX hosts_groups_old_pkey;


--
-- Name: hosts_groups hosts_groups_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_groups
    ADD CONSTRAINT hosts_groups_pkey PRIMARY KEY (org_id, host_id, group_id);


--
-- Name: hosts_groups_p0 hosts_groups_p0_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_groups_p0
    ADD CONSTRAINT hosts_groups_p0_pkey PRIMARY KEY (org_id, host_id, group_id);


--
-- Name: hosts_groups_p1 hosts_groups_p1_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_groups_p1
    ADD CONSTRAINT hosts_groups_p1_pkey PRIMARY KEY (org_id, host_id, group_id);


--
-- Name: hosts_groups_old hosts_groups_unique_host_id; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_groups_old
    ADD CONSTRAINT hosts_groups_unique_host_id UNIQUE (host_id);


--
-- Name: hosts_old hosts_old_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_old
    ADD CONSTRAINT hosts_old_pkey PRIMARY KEY (id);

ALTER TABLE ONLY hbi.hosts_old REPLICA IDENTITY USING INDEX hosts_old_pkey;


--
-- Name: hosts hosts_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts
    ADD CONSTRAINT hosts_pkey PRIMARY KEY (org_id, id);


--
-- Name: hosts_p0 hosts_p0_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_p0
    ADD CONSTRAINT hosts_p0_pkey PRIMARY KEY (org_id, id);


--
-- Name: hosts_p1 hosts_p1_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_p1
    ADD CONSTRAINT hosts_p1_pkey PRIMARY KEY (org_id, id);


--
-- Name: outbox outbox_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.outbox
    ADD CONSTRAINT outbox_pkey PRIMARY KEY (id);


--
-- Name: system_profiles_dynamic pk_system_profiles_dynamic; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.system_profiles_dynamic
    ADD CONSTRAINT pk_system_profiles_dynamic PRIMARY KEY (org_id, host_id);


--
-- Name: system_profiles_static pk_system_profiles_static; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.system_profiles_static
    ADD CONSTRAINT pk_system_profiles_static PRIMARY KEY (org_id, host_id);


--
-- Name: staleness staleness_org_id_key; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.staleness
    ADD CONSTRAINT staleness_org_id_key UNIQUE (org_id);


--
-- Name: staleness staleness_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.staleness
    ADD CONSTRAINT staleness_pkey PRIMARY KEY (id);

ALTER TABLE ONLY hbi.staleness REPLICA IDENTITY USING INDEX staleness_pkey;


--
-- Name: system_profiles_dynamic_p0 system_profiles_dynamic_p0_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.system_profiles_dynamic_p0
    ADD CONSTRAINT system_profiles_dynamic_p0_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: system_profiles_dynamic_p1 system_profiles_dynamic_p1_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.system_profiles_dynamic_p1
    ADD CONSTRAINT system_profiles_dynamic_p1_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: system_profiles_static_p0 system_profiles_static_p0_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.system_profiles_static_p0
    ADD CONSTRAINT system_profiles_static_p0_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: system_profiles_static_p1 system_profiles_static_p1_pkey; Type: CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.system_profiles_static_p1
    ADD CONSTRAINT system_profiles_static_p1_pkey PRIMARY KEY (org_id, host_id);


--
-- Name: idx_hosts_groups_reverse; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_groups_reverse ON ONLY hbi.hosts_groups USING btree (org_id, group_id, host_id);


--
-- Name: hosts_groups_p0_org_id_group_id_host_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_groups_p0_org_id_group_id_host_id_idx ON hbi.hosts_groups_p0 USING btree (org_id, group_id, host_id);


--
-- Name: idx_hosts_groups_forward; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_groups_forward ON ONLY hbi.hosts_groups USING btree (org_id, host_id, group_id);


--
-- Name: hosts_groups_p0_org_id_host_id_group_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_groups_p0_org_id_host_id_group_id_idx ON hbi.hosts_groups_p0 USING btree (org_id, host_id, group_id);


--
-- Name: hosts_groups_p1_org_id_group_id_host_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_groups_p1_org_id_group_id_host_id_idx ON hbi.hosts_groups_p1 USING btree (org_id, group_id, host_id);


--
-- Name: hosts_groups_p1_org_id_host_id_group_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_groups_p1_org_id_host_id_group_id_idx ON hbi.hosts_groups_p1 USING btree (org_id, host_id, group_id);


--
-- Name: hosts_modified_on_id; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_modified_on_id ON hbi.hosts_old USING btree (modified_on DESC, id DESC);


--
-- Name: idx_hosts_sap_system; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_sap_system ON ONLY hbi.hosts USING btree ((((system_profile_facts ->> 'sap_system'::text))::boolean));


--
-- Name: hosts_p0_bool_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p0_bool_idx ON hbi.hosts_p0 USING btree ((((system_profile_facts ->> 'sap_system'::text))::boolean));


--
-- Name: idx_hosts_host_type; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_host_type ON ONLY hbi.hosts USING btree (((system_profile_facts ->> 'host_type'::text)));


--
-- Name: hosts_p0_expr_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p0_expr_idx ON hbi.hosts_p0 USING btree (((system_profile_facts ->> 'host_type'::text)));


--
-- Name: idx_hosts_mssql; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_mssql ON ONLY hbi.hosts USING btree (((system_profile_facts ->> 'mssql'::text)));


--
-- Name: hosts_p0_expr_idx3; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p0_expr_idx3 ON hbi.hosts_p0 USING btree (((system_profile_facts ->> 'mssql'::text)));


--
-- Name: idx_hosts_ansible; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_ansible ON ONLY hbi.hosts USING btree (((system_profile_facts ->> 'ansible'::text)));


--
-- Name: hosts_p0_expr_idx4; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p0_expr_idx4 ON hbi.hosts_p0 USING btree (((system_profile_facts ->> 'ansible'::text)));


--
-- Name: idx_hosts_system_profiles_workloads_gin; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_system_profiles_workloads_gin ON ONLY hbi.hosts USING gin (((system_profile_facts -> 'workloads'::text)));


--
-- Name: hosts_p0_expr_idx5; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p0_expr_idx5 ON hbi.hosts_p0 USING gin (((system_profile_facts -> 'workloads'::text)));


--
-- Name: idx_hosts_operating_system_multi; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_operating_system_multi ON ONLY hbi.hosts USING btree ((((system_profile_facts -> 'operating_system'::text) ->> 'name'::text)), ((((system_profile_facts -> 'operating_system'::text) ->> 'major'::text))::integer), ((((system_profile_facts -> 'operating_system'::text) ->> 'minor'::text))::integer), ((system_profile_facts ->> 'host_type'::text)), modified_on, org_id) WHERE ((system_profile_facts -> 'operating_system'::text) IS NOT NULL);


--
-- Name: hosts_p0_expr_int4_int41_expr1_modified_on_org_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p0_expr_int4_int41_expr1_modified_on_org_id_idx ON hbi.hosts_p0 USING btree ((((system_profile_facts -> 'operating_system'::text) ->> 'name'::text)), ((((system_profile_facts -> 'operating_system'::text) ->> 'major'::text))::integer), ((((system_profile_facts -> 'operating_system'::text) ->> 'minor'::text))::integer), ((system_profile_facts ->> 'host_type'::text)), modified_on, org_id) WHERE ((system_profile_facts -> 'operating_system'::text) IS NOT NULL);


--
-- Name: idx_hosts_groups_gin; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_groups_gin ON ONLY hbi.hosts USING gin (groups);


--
-- Name: hosts_p0_groups_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p0_groups_idx ON hbi.hosts_p0 USING gin (groups);


--
-- Name: idx_hosts_host_type_id; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_host_type_id ON ONLY hbi.hosts USING btree (host_type, id);


--
-- Name: hosts_p0_host_type_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p0_host_type_id_idx ON hbi.hosts_p0 USING btree (host_type, id);


--
-- Name: idx_hosts_insights_id; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_insights_id ON ONLY hbi.hosts USING btree (insights_id);


--
-- Name: hosts_p0_insights_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p0_insights_id_idx ON hbi.hosts_p0 USING btree (insights_id);


--
-- Name: idx_hosts_last_check_in_id; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_last_check_in_id ON ONLY hbi.hosts USING btree (last_check_in, id);


--
-- Name: hosts_p0_last_check_in_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p0_last_check_in_id_idx ON hbi.hosts_p0 USING btree (last_check_in, id);


--
-- Name: idx_hosts_modified_on_id; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_modified_on_id ON ONLY hbi.hosts USING btree (modified_on DESC, id DESC);


--
-- Name: hosts_p0_modified_on_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p0_modified_on_id_idx ON hbi.hosts_p0 USING btree (modified_on DESC, id DESC);


--
-- Name: hosts_replica_identity_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE UNIQUE INDEX hosts_replica_identity_idx ON ONLY hbi.hosts USING btree (org_id, id, insights_id);

ALTER TABLE ONLY hbi.hosts REPLICA IDENTITY USING INDEX hosts_replica_identity_idx;


--
-- Name: hosts_p0_org_id_id_insights_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE UNIQUE INDEX hosts_p0_org_id_id_insights_id_idx ON hbi.hosts_p0 USING btree (org_id, id, insights_id);

ALTER TABLE ONLY hbi.hosts_p0 REPLICA IDENTITY USING INDEX hosts_p0_org_id_id_insights_id_idx;


--
-- Name: idx_hosts_bootc_status; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_bootc_status ON ONLY hbi.hosts USING btree (org_id) WHERE ((((system_profile_facts -> 'bootc_status'::text) -> 'booted'::text) ->> 'image_digest'::text) IS NOT NULL);


--
-- Name: hosts_p0_org_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p0_org_id_idx ON hbi.hosts_p0 USING btree (org_id) WHERE ((((system_profile_facts -> 'bootc_status'::text) -> 'booted'::text) ->> 'image_digest'::text) IS NOT NULL);


--
-- Name: idx_hosts_host_type_modified_on_org_id; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_host_type_modified_on_org_id ON ONLY hbi.hosts USING btree (org_id, modified_on, ((system_profile_facts ->> 'host_type'::text)));


--
-- Name: hosts_p0_org_id_modified_on_expr_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p0_org_id_modified_on_expr_idx ON hbi.hosts_p0 USING btree (org_id, modified_on, ((system_profile_facts ->> 'host_type'::text)));


--
-- Name: idx_hosts_subscription_manager_id; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_hosts_subscription_manager_id ON ONLY hbi.hosts USING btree (subscription_manager_id);


--
-- Name: hosts_p0_subscription_manager_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p0_subscription_manager_id_idx ON hbi.hosts_p0 USING btree (subscription_manager_id);


--
-- Name: hosts_p1_bool_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p1_bool_idx ON hbi.hosts_p1 USING btree ((((system_profile_facts ->> 'sap_system'::text))::boolean));


--
-- Name: hosts_p1_expr_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p1_expr_idx ON hbi.hosts_p1 USING btree (((system_profile_facts ->> 'host_type'::text)));


--
-- Name: hosts_p1_expr_idx3; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p1_expr_idx3 ON hbi.hosts_p1 USING btree (((system_profile_facts ->> 'mssql'::text)));


--
-- Name: hosts_p1_expr_idx4; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p1_expr_idx4 ON hbi.hosts_p1 USING btree (((system_profile_facts ->> 'ansible'::text)));


--
-- Name: hosts_p1_expr_idx5; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p1_expr_idx5 ON hbi.hosts_p1 USING gin (((system_profile_facts -> 'workloads'::text)));


--
-- Name: hosts_p1_expr_int4_int41_expr1_modified_on_org_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p1_expr_int4_int41_expr1_modified_on_org_id_idx ON hbi.hosts_p1 USING btree ((((system_profile_facts -> 'operating_system'::text) ->> 'name'::text)), ((((system_profile_facts -> 'operating_system'::text) ->> 'major'::text))::integer), ((((system_profile_facts -> 'operating_system'::text) ->> 'minor'::text))::integer), ((system_profile_facts ->> 'host_type'::text)), modified_on, org_id) WHERE ((system_profile_facts -> 'operating_system'::text) IS NOT NULL);


--
-- Name: hosts_p1_groups_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p1_groups_idx ON hbi.hosts_p1 USING gin (groups);


--
-- Name: hosts_p1_host_type_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p1_host_type_id_idx ON hbi.hosts_p1 USING btree (host_type, id);


--
-- Name: hosts_p1_insights_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p1_insights_id_idx ON hbi.hosts_p1 USING btree (insights_id);


--
-- Name: hosts_p1_last_check_in_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p1_last_check_in_id_idx ON hbi.hosts_p1 USING btree (last_check_in, id);


--
-- Name: hosts_p1_modified_on_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p1_modified_on_id_idx ON hbi.hosts_p1 USING btree (modified_on DESC, id DESC);


--
-- Name: hosts_p1_org_id_id_insights_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE UNIQUE INDEX hosts_p1_org_id_id_insights_id_idx ON hbi.hosts_p1 USING btree (org_id, id, insights_id);

ALTER TABLE ONLY hbi.hosts_p1 REPLICA IDENTITY USING INDEX hosts_p1_org_id_id_insights_id_idx;


--
-- Name: hosts_p1_org_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p1_org_id_idx ON hbi.hosts_p1 USING btree (org_id) WHERE ((((system_profile_facts -> 'bootc_status'::text) -> 'booted'::text) ->> 'image_digest'::text) IS NOT NULL);


--
-- Name: hosts_p1_org_id_modified_on_expr_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p1_org_id_modified_on_expr_idx ON hbi.hosts_p1 USING btree (org_id, modified_on, ((system_profile_facts ->> 'host_type'::text)));


--
-- Name: hosts_p1_subscription_manager_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX hosts_p1_subscription_manager_id_idx ON hbi.hosts_p1 USING btree (subscription_manager_id);


--
-- Name: idx_groups_org_id_name_ignorecase; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_groups_org_id_name_ignorecase ON hbi.groups USING btree (lower((name)::text), org_id);


--
-- Name: idx_host_type; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_host_type ON hbi.hosts_old USING btree (((system_profile_facts ->> 'host_type'::text)));


--
-- Name: idx_host_type_modified_on_org_id; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_host_type_modified_on_org_id ON hbi.hosts_old USING btree (org_id, modified_on, ((system_profile_facts ->> 'host_type'::text)));


--
-- Name: idx_operating_system_multi; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_operating_system_multi ON hbi.hosts_old USING btree ((((system_profile_facts -> 'operating_system'::text) ->> 'name'::text)), ((((system_profile_facts -> 'operating_system'::text) ->> 'major'::text))::integer), ((((system_profile_facts -> 'operating_system'::text) ->> 'minor'::text))::integer), ((system_profile_facts ->> 'host_type'::text)), modified_on, org_id) WHERE ((system_profile_facts -> 'operating_system'::text) IS NOT NULL);


--
-- Name: idx_system_profiles_dynamic_replica_identity; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE UNIQUE INDEX idx_system_profiles_dynamic_replica_identity ON ONLY hbi.system_profiles_dynamic USING btree (org_id, host_id, insights_id);

ALTER TABLE ONLY hbi.system_profiles_dynamic REPLICA IDENTITY USING INDEX idx_system_profiles_dynamic_replica_identity;


--
-- Name: idx_system_profiles_dynamic_workloads_gin; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_system_profiles_dynamic_workloads_gin ON ONLY hbi.system_profiles_dynamic USING gin (workloads);


--
-- Name: idx_system_profiles_static_bootc_image_digest; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_system_profiles_static_bootc_image_digest ON ONLY hbi.system_profiles_static USING btree ((((bootc_status -> 'booted'::text) ->> 'image_digest'::text)));


--
-- Name: idx_system_profiles_static_bootc_status; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_system_profiles_static_bootc_status ON ONLY hbi.system_profiles_static USING btree (bootc_status);


--
-- Name: idx_system_profiles_static_host_id; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_system_profiles_static_host_id ON ONLY hbi.system_profiles_static USING btree (host_id);


--
-- Name: idx_system_profiles_static_host_type; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_system_profiles_static_host_type ON ONLY hbi.system_profiles_static USING btree (host_type);


--
-- Name: idx_system_profiles_static_operating_system_multi; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_system_profiles_static_operating_system_multi ON ONLY hbi.system_profiles_static USING btree (((operating_system ->> 'name'::text)), (((operating_system ->> 'major'::text))::integer), (((operating_system ->> 'minor'::text))::integer), org_id) WHERE (operating_system IS NOT NULL);


--
-- Name: idx_system_profiles_static_org_id; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_system_profiles_static_org_id ON ONLY hbi.system_profiles_static USING btree (org_id);


--
-- Name: idx_system_profiles_static_replica_identity; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE UNIQUE INDEX idx_system_profiles_static_replica_identity ON ONLY hbi.system_profiles_static USING btree (org_id, host_id, insights_id);

ALTER TABLE ONLY hbi.system_profiles_static REPLICA IDENTITY USING INDEX idx_system_profiles_static_replica_identity;


--
-- Name: idx_system_profiles_static_rhc_client_id; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_system_profiles_static_rhc_client_id ON ONLY hbi.system_profiles_static USING btree (rhc_client_id);


--
-- Name: idx_system_profiles_static_system_update_method; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idx_system_profiles_static_system_update_method ON ONLY hbi.system_profiles_static USING btree (system_update_method);


--
-- Name: idxaccstaleorgid; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idxaccstaleorgid ON hbi.staleness USING btree (org_id);


--
-- Name: idxansible; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idxansible ON hbi.hosts_old USING btree (((system_profile_facts ->> 'ansible'::text)));


--
-- Name: idxbootc_status; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idxbootc_status ON hbi.hosts_old USING btree (org_id) WHERE ((((system_profile_facts -> 'bootc_status'::text) -> 'booted'::text) ->> 'image_digest'::text) IS NOT NULL);


--
-- Name: idxgincanonicalfacts; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idxgincanonicalfacts ON hbi.hosts_old USING gin (canonical_facts jsonb_path_ops);


--
-- Name: idxgrouporgid; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idxgrouporgid ON hbi.groups USING btree (org_id);


--
-- Name: idxgroupshosts; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE UNIQUE INDEX idxgroupshosts ON hbi.hosts_groups_old USING btree (group_id, host_id);


--
-- Name: idxhostsgroups; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE UNIQUE INDEX idxhostsgroups ON hbi.hosts_groups_old USING btree (host_id, group_id);


--
-- Name: idxinsightsid; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idxinsightsid ON hbi.hosts_old USING btree (((canonical_facts ->> 'insights_id'::text)));


--
-- Name: idxmssql; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idxmssql ON hbi.hosts_old USING btree (((system_profile_facts ->> 'mssql'::text)));


--
-- Name: idxorgid; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idxorgid ON hbi.hosts_old USING btree (org_id);


--
-- Name: idxorgidungrouped; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idxorgidungrouped ON hbi.groups USING btree (org_id, ungrouped);


--
-- Name: idxsap_system; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX idxsap_system ON hbi.hosts_old USING btree ((((system_profile_facts ->> 'sap_system'::text))::boolean));


--
-- Name: system_profiles_dynamic_p0_org_id_host_id_insights_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE UNIQUE INDEX system_profiles_dynamic_p0_org_id_host_id_insights_id_idx ON hbi.system_profiles_dynamic_p0 USING btree (org_id, host_id, insights_id);

ALTER TABLE ONLY hbi.system_profiles_dynamic_p0 REPLICA IDENTITY USING INDEX system_profiles_dynamic_p0_org_id_host_id_insights_id_idx;


--
-- Name: system_profiles_dynamic_p0_workloads_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_dynamic_p0_workloads_idx ON hbi.system_profiles_dynamic_p0 USING gin (workloads);


--
-- Name: system_profiles_dynamic_p1_org_id_host_id_insights_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE UNIQUE INDEX system_profiles_dynamic_p1_org_id_host_id_insights_id_idx ON hbi.system_profiles_dynamic_p1 USING btree (org_id, host_id, insights_id);

ALTER TABLE ONLY hbi.system_profiles_dynamic_p1 REPLICA IDENTITY USING INDEX system_profiles_dynamic_p1_org_id_host_id_insights_id_idx;


--
-- Name: system_profiles_dynamic_p1_workloads_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_dynamic_p1_workloads_idx ON hbi.system_profiles_dynamic_p1 USING gin (workloads);


--
-- Name: system_profiles_static_p0_bootc_status_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p0_bootc_status_idx ON hbi.system_profiles_static_p0 USING btree (bootc_status);


--
-- Name: system_profiles_static_p0_expr_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p0_expr_idx ON hbi.system_profiles_static_p0 USING btree ((((bootc_status -> 'booted'::text) ->> 'image_digest'::text)));


--
-- Name: system_profiles_static_p0_expr_int4_int41_org_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p0_expr_int4_int41_org_id_idx ON hbi.system_profiles_static_p0 USING btree (((operating_system ->> 'name'::text)), (((operating_system ->> 'major'::text))::integer), (((operating_system ->> 'minor'::text))::integer), org_id) WHERE (operating_system IS NOT NULL);


--
-- Name: system_profiles_static_p0_host_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p0_host_id_idx ON hbi.system_profiles_static_p0 USING btree (host_id);


--
-- Name: system_profiles_static_p0_host_type_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p0_host_type_idx ON hbi.system_profiles_static_p0 USING btree (host_type);


--
-- Name: system_profiles_static_p0_org_id_host_id_insights_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE UNIQUE INDEX system_profiles_static_p0_org_id_host_id_insights_id_idx ON hbi.system_profiles_static_p0 USING btree (org_id, host_id, insights_id);

ALTER TABLE ONLY hbi.system_profiles_static_p0 REPLICA IDENTITY USING INDEX system_profiles_static_p0_org_id_host_id_insights_id_idx;


--
-- Name: system_profiles_static_p0_org_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p0_org_id_idx ON hbi.system_profiles_static_p0 USING btree (org_id);


--
-- Name: system_profiles_static_p0_rhc_client_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p0_rhc_client_id_idx ON hbi.system_profiles_static_p0 USING btree (rhc_client_id);


--
-- Name: system_profiles_static_p0_system_update_method_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p0_system_update_method_idx ON hbi.system_profiles_static_p0 USING btree (system_update_method);


--
-- Name: system_profiles_static_p1_bootc_status_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p1_bootc_status_idx ON hbi.system_profiles_static_p1 USING btree (bootc_status);


--
-- Name: system_profiles_static_p1_expr_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p1_expr_idx ON hbi.system_profiles_static_p1 USING btree ((((bootc_status -> 'booted'::text) ->> 'image_digest'::text)));


--
-- Name: system_profiles_static_p1_expr_int4_int41_org_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p1_expr_int4_int41_org_id_idx ON hbi.system_profiles_static_p1 USING btree (((operating_system ->> 'name'::text)), (((operating_system ->> 'major'::text))::integer), (((operating_system ->> 'minor'::text))::integer), org_id) WHERE (operating_system IS NOT NULL);


--
-- Name: system_profiles_static_p1_host_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p1_host_id_idx ON hbi.system_profiles_static_p1 USING btree (host_id);


--
-- Name: system_profiles_static_p1_host_type_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p1_host_type_idx ON hbi.system_profiles_static_p1 USING btree (host_type);


--
-- Name: system_profiles_static_p1_org_id_host_id_insights_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE UNIQUE INDEX system_profiles_static_p1_org_id_host_id_insights_id_idx ON hbi.system_profiles_static_p1 USING btree (org_id, host_id, insights_id);

ALTER TABLE ONLY hbi.system_profiles_static_p1 REPLICA IDENTITY USING INDEX system_profiles_static_p1_org_id_host_id_insights_id_idx;


--
-- Name: system_profiles_static_p1_org_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p1_org_id_idx ON hbi.system_profiles_static_p1 USING btree (org_id);


--
-- Name: system_profiles_static_p1_rhc_client_id_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p1_rhc_client_id_idx ON hbi.system_profiles_static_p1 USING btree (rhc_client_id);


--
-- Name: system_profiles_static_p1_system_update_method_idx; Type: INDEX; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE INDEX system_profiles_static_p1_system_update_method_idx ON hbi.system_profiles_static_p1 USING btree (system_update_method);


--
-- Name: hosts_app_data_advisor_p0_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_hosts_app_data_advisor ATTACH PARTITION hbi.hosts_app_data_advisor_p0_pkey;


--
-- Name: hosts_app_data_advisor_p1_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_hosts_app_data_advisor ATTACH PARTITION hbi.hosts_app_data_advisor_p1_pkey;


--
-- Name: hosts_app_data_compliance_p0_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_hosts_app_data_compliance ATTACH PARTITION hbi.hosts_app_data_compliance_p0_pkey;


--
-- Name: hosts_app_data_compliance_p1_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_hosts_app_data_compliance ATTACH PARTITION hbi.hosts_app_data_compliance_p1_pkey;


--
-- Name: hosts_app_data_image_builder_p0_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_hosts_app_data_image_builder ATTACH PARTITION hbi.hosts_app_data_image_builder_p0_pkey;


--
-- Name: hosts_app_data_image_builder_p1_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_hosts_app_data_image_builder ATTACH PARTITION hbi.hosts_app_data_image_builder_p1_pkey;


--
-- Name: hosts_app_data_malware_p0_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_hosts_app_data_malware ATTACH PARTITION hbi.hosts_app_data_malware_p0_pkey;


--
-- Name: hosts_app_data_malware_p1_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_hosts_app_data_malware ATTACH PARTITION hbi.hosts_app_data_malware_p1_pkey;


--
-- Name: hosts_app_data_patch_p0_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_hosts_app_data_patch ATTACH PARTITION hbi.hosts_app_data_patch_p0_pkey;


--
-- Name: hosts_app_data_patch_p1_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_hosts_app_data_patch ATTACH PARTITION hbi.hosts_app_data_patch_p1_pkey;


--
-- Name: hosts_app_data_remediations_p0_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_hosts_app_data_remediations ATTACH PARTITION hbi.hosts_app_data_remediations_p0_pkey;


--
-- Name: hosts_app_data_remediations_p1_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_hosts_app_data_remediations ATTACH PARTITION hbi.hosts_app_data_remediations_p1_pkey;


--
-- Name: hosts_app_data_vulnerability_p0_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_hosts_app_data_vulnerability ATTACH PARTITION hbi.hosts_app_data_vulnerability_p0_pkey;


--
-- Name: hosts_app_data_vulnerability_p1_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_hosts_app_data_vulnerability ATTACH PARTITION hbi.hosts_app_data_vulnerability_p1_pkey;


--
-- Name: hosts_groups_p0_org_id_group_id_host_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_groups_reverse ATTACH PARTITION hbi.hosts_groups_p0_org_id_group_id_host_id_idx;


--
-- Name: hosts_groups_p0_org_id_host_id_group_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_groups_forward ATTACH PARTITION hbi.hosts_groups_p0_org_id_host_id_group_id_idx;


--
-- Name: hosts_groups_p0_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.hosts_groups_pkey ATTACH PARTITION hbi.hosts_groups_p0_pkey;


--
-- Name: hosts_groups_p1_org_id_group_id_host_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_groups_reverse ATTACH PARTITION hbi.hosts_groups_p1_org_id_group_id_host_id_idx;


--
-- Name: hosts_groups_p1_org_id_host_id_group_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_groups_forward ATTACH PARTITION hbi.hosts_groups_p1_org_id_host_id_group_id_idx;


--
-- Name: hosts_groups_p1_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.hosts_groups_pkey ATTACH PARTITION hbi.hosts_groups_p1_pkey;


--
-- Name: hosts_p0_bool_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_sap_system ATTACH PARTITION hbi.hosts_p0_bool_idx;


--
-- Name: hosts_p0_expr_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_host_type ATTACH PARTITION hbi.hosts_p0_expr_idx;


--
-- Name: hosts_p0_expr_idx3; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_mssql ATTACH PARTITION hbi.hosts_p0_expr_idx3;


--
-- Name: hosts_p0_expr_idx4; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_ansible ATTACH PARTITION hbi.hosts_p0_expr_idx4;


--
-- Name: hosts_p0_expr_idx5; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_system_profiles_workloads_gin ATTACH PARTITION hbi.hosts_p0_expr_idx5;


--
-- Name: hosts_p0_expr_int4_int41_expr1_modified_on_org_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_operating_system_multi ATTACH PARTITION hbi.hosts_p0_expr_int4_int41_expr1_modified_on_org_id_idx;


--
-- Name: hosts_p0_groups_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_groups_gin ATTACH PARTITION hbi.hosts_p0_groups_idx;


--
-- Name: hosts_p0_host_type_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_host_type_id ATTACH PARTITION hbi.hosts_p0_host_type_id_idx;


--
-- Name: hosts_p0_insights_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_insights_id ATTACH PARTITION hbi.hosts_p0_insights_id_idx;


--
-- Name: hosts_p0_last_check_in_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_last_check_in_id ATTACH PARTITION hbi.hosts_p0_last_check_in_id_idx;


--
-- Name: hosts_p0_modified_on_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_modified_on_id ATTACH PARTITION hbi.hosts_p0_modified_on_id_idx;


--
-- Name: hosts_p0_org_id_id_insights_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.hosts_replica_identity_idx ATTACH PARTITION hbi.hosts_p0_org_id_id_insights_id_idx;


--
-- Name: hosts_p0_org_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_bootc_status ATTACH PARTITION hbi.hosts_p0_org_id_idx;


--
-- Name: hosts_p0_org_id_modified_on_expr_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_host_type_modified_on_org_id ATTACH PARTITION hbi.hosts_p0_org_id_modified_on_expr_idx;


--
-- Name: hosts_p0_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.hosts_pkey ATTACH PARTITION hbi.hosts_p0_pkey;


--
-- Name: hosts_p0_subscription_manager_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_subscription_manager_id ATTACH PARTITION hbi.hosts_p0_subscription_manager_id_idx;


--
-- Name: hosts_p1_bool_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_sap_system ATTACH PARTITION hbi.hosts_p1_bool_idx;


--
-- Name: hosts_p1_expr_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_host_type ATTACH PARTITION hbi.hosts_p1_expr_idx;


--
-- Name: hosts_p1_expr_idx3; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_mssql ATTACH PARTITION hbi.hosts_p1_expr_idx3;


--
-- Name: hosts_p1_expr_idx4; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_ansible ATTACH PARTITION hbi.hosts_p1_expr_idx4;


--
-- Name: hosts_p1_expr_idx5; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_system_profiles_workloads_gin ATTACH PARTITION hbi.hosts_p1_expr_idx5;


--
-- Name: hosts_p1_expr_int4_int41_expr1_modified_on_org_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_operating_system_multi ATTACH PARTITION hbi.hosts_p1_expr_int4_int41_expr1_modified_on_org_id_idx;


--
-- Name: hosts_p1_groups_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_groups_gin ATTACH PARTITION hbi.hosts_p1_groups_idx;


--
-- Name: hosts_p1_host_type_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_host_type_id ATTACH PARTITION hbi.hosts_p1_host_type_id_idx;


--
-- Name: hosts_p1_insights_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_insights_id ATTACH PARTITION hbi.hosts_p1_insights_id_idx;


--
-- Name: hosts_p1_last_check_in_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_last_check_in_id ATTACH PARTITION hbi.hosts_p1_last_check_in_id_idx;


--
-- Name: hosts_p1_modified_on_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_modified_on_id ATTACH PARTITION hbi.hosts_p1_modified_on_id_idx;


--
-- Name: hosts_p1_org_id_id_insights_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.hosts_replica_identity_idx ATTACH PARTITION hbi.hosts_p1_org_id_id_insights_id_idx;


--
-- Name: hosts_p1_org_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_bootc_status ATTACH PARTITION hbi.hosts_p1_org_id_idx;


--
-- Name: hosts_p1_org_id_modified_on_expr_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_host_type_modified_on_org_id ATTACH PARTITION hbi.hosts_p1_org_id_modified_on_expr_idx;


--
-- Name: hosts_p1_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.hosts_pkey ATTACH PARTITION hbi.hosts_p1_pkey;


--
-- Name: hosts_p1_subscription_manager_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_hosts_subscription_manager_id ATTACH PARTITION hbi.hosts_p1_subscription_manager_id_idx;


--
-- Name: system_profiles_dynamic_p0_org_id_host_id_insights_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_dynamic_replica_identity ATTACH PARTITION hbi.system_profiles_dynamic_p0_org_id_host_id_insights_id_idx;


--
-- Name: system_profiles_dynamic_p0_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_system_profiles_dynamic ATTACH PARTITION hbi.system_profiles_dynamic_p0_pkey;


--
-- Name: system_profiles_dynamic_p0_workloads_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_dynamic_workloads_gin ATTACH PARTITION hbi.system_profiles_dynamic_p0_workloads_idx;


--
-- Name: system_profiles_dynamic_p1_org_id_host_id_insights_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_dynamic_replica_identity ATTACH PARTITION hbi.system_profiles_dynamic_p1_org_id_host_id_insights_id_idx;


--
-- Name: system_profiles_dynamic_p1_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_system_profiles_dynamic ATTACH PARTITION hbi.system_profiles_dynamic_p1_pkey;


--
-- Name: system_profiles_dynamic_p1_workloads_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_dynamic_workloads_gin ATTACH PARTITION hbi.system_profiles_dynamic_p1_workloads_idx;


--
-- Name: system_profiles_static_p0_bootc_status_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_bootc_status ATTACH PARTITION hbi.system_profiles_static_p0_bootc_status_idx;


--
-- Name: system_profiles_static_p0_expr_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_bootc_image_digest ATTACH PARTITION hbi.system_profiles_static_p0_expr_idx;


--
-- Name: system_profiles_static_p0_expr_int4_int41_org_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_operating_system_multi ATTACH PARTITION hbi.system_profiles_static_p0_expr_int4_int41_org_id_idx;


--
-- Name: system_profiles_static_p0_host_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_host_id ATTACH PARTITION hbi.system_profiles_static_p0_host_id_idx;


--
-- Name: system_profiles_static_p0_host_type_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_host_type ATTACH PARTITION hbi.system_profiles_static_p0_host_type_idx;


--
-- Name: system_profiles_static_p0_org_id_host_id_insights_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_replica_identity ATTACH PARTITION hbi.system_profiles_static_p0_org_id_host_id_insights_id_idx;


--
-- Name: system_profiles_static_p0_org_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_org_id ATTACH PARTITION hbi.system_profiles_static_p0_org_id_idx;


--
-- Name: system_profiles_static_p0_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_system_profiles_static ATTACH PARTITION hbi.system_profiles_static_p0_pkey;


--
-- Name: system_profiles_static_p0_rhc_client_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_rhc_client_id ATTACH PARTITION hbi.system_profiles_static_p0_rhc_client_id_idx;


--
-- Name: system_profiles_static_p0_system_update_method_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_system_update_method ATTACH PARTITION hbi.system_profiles_static_p0_system_update_method_idx;


--
-- Name: system_profiles_static_p1_bootc_status_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_bootc_status ATTACH PARTITION hbi.system_profiles_static_p1_bootc_status_idx;


--
-- Name: system_profiles_static_p1_expr_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_bootc_image_digest ATTACH PARTITION hbi.system_profiles_static_p1_expr_idx;


--
-- Name: system_profiles_static_p1_expr_int4_int41_org_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_operating_system_multi ATTACH PARTITION hbi.system_profiles_static_p1_expr_int4_int41_org_id_idx;


--
-- Name: system_profiles_static_p1_host_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_host_id ATTACH PARTITION hbi.system_profiles_static_p1_host_id_idx;


--
-- Name: system_profiles_static_p1_host_type_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_host_type ATTACH PARTITION hbi.system_profiles_static_p1_host_type_idx;


--
-- Name: system_profiles_static_p1_org_id_host_id_insights_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_replica_identity ATTACH PARTITION hbi.system_profiles_static_p1_org_id_host_id_insights_id_idx;


--
-- Name: system_profiles_static_p1_org_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_org_id ATTACH PARTITION hbi.system_profiles_static_p1_org_id_idx;


--
-- Name: system_profiles_static_p1_pkey; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.pk_system_profiles_static ATTACH PARTITION hbi.system_profiles_static_p1_pkey;


--
-- Name: system_profiles_static_p1_rhc_client_id_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_rhc_client_id ATTACH PARTITION hbi.system_profiles_static_p1_rhc_client_id_idx;


--
-- Name: system_profiles_static_p1_system_update_method_idx; Type: INDEX ATTACH; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER INDEX hbi.idx_system_profiles_static_system_update_method ATTACH PARTITION hbi.system_profiles_static_p1_system_update_method_idx;


--
-- Name: system_profiles_dynamic trigger_populate_system_profiles_dynamic_insights_id; Type: TRIGGER; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TRIGGER trigger_populate_system_profiles_dynamic_insights_id AFTER INSERT ON hbi.system_profiles_dynamic FOR EACH ROW EXECUTE FUNCTION hbi.populate_system_profiles_dynamic_insights_id();


--
-- Name: system_profiles_static trigger_populate_system_profiles_static_insights_id; Type: TRIGGER; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TRIGGER trigger_populate_system_profiles_static_insights_id AFTER INSERT ON hbi.system_profiles_static FOR EACH ROW EXECUTE FUNCTION hbi.populate_system_profiles_static_insights_id();


--
-- Name: hosts trigger_sync_insights_id_to_system_profiles; Type: TRIGGER; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

CREATE TRIGGER trigger_sync_insights_id_to_system_profiles AFTER UPDATE OF insights_id ON hbi.hosts FOR EACH ROW EXECUTE FUNCTION hbi.sync_insights_id_to_system_profiles();


--
-- Name: hosts_app_data_advisor fk_hosts_app_data_advisor_hosts; Type: FK CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE hbi.hosts_app_data_advisor
    ADD CONSTRAINT fk_hosts_app_data_advisor_hosts FOREIGN KEY (org_id, host_id) REFERENCES hbi.hosts(org_id, id) ON DELETE CASCADE;


--
-- Name: hosts_app_data_compliance fk_hosts_app_data_compliance_hosts; Type: FK CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE hbi.hosts_app_data_compliance
    ADD CONSTRAINT fk_hosts_app_data_compliance_hosts FOREIGN KEY (org_id, host_id) REFERENCES hbi.hosts(org_id, id) ON DELETE CASCADE;


--
-- Name: hosts_app_data_image_builder fk_hosts_app_data_image_builder_hosts; Type: FK CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE hbi.hosts_app_data_image_builder
    ADD CONSTRAINT fk_hosts_app_data_image_builder_hosts FOREIGN KEY (org_id, host_id) REFERENCES hbi.hosts(org_id, id) ON DELETE CASCADE;


--
-- Name: hosts_app_data_malware fk_hosts_app_data_malware_hosts; Type: FK CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE hbi.hosts_app_data_malware
    ADD CONSTRAINT fk_hosts_app_data_malware_hosts FOREIGN KEY (org_id, host_id) REFERENCES hbi.hosts(org_id, id) ON DELETE CASCADE;


--
-- Name: hosts_app_data_patch fk_hosts_app_data_patch_hosts; Type: FK CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE hbi.hosts_app_data_patch
    ADD CONSTRAINT fk_hosts_app_data_patch_hosts FOREIGN KEY (org_id, host_id) REFERENCES hbi.hosts(org_id, id) ON DELETE CASCADE;


--
-- Name: hosts_app_data_remediations fk_hosts_app_data_remediations_hosts; Type: FK CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE hbi.hosts_app_data_remediations
    ADD CONSTRAINT fk_hosts_app_data_remediations_hosts FOREIGN KEY (org_id, host_id) REFERENCES hbi.hosts(org_id, id) ON DELETE CASCADE;


--
-- Name: hosts_app_data_vulnerability fk_hosts_app_data_vulnerability_hosts; Type: FK CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE hbi.hosts_app_data_vulnerability
    ADD CONSTRAINT fk_hosts_app_data_vulnerability_hosts FOREIGN KEY (org_id, host_id) REFERENCES hbi.hosts(org_id, id) ON DELETE CASCADE;


--
-- Name: hosts_groups fk_hosts_groups_on_groups; Type: FK CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE hbi.hosts_groups
    ADD CONSTRAINT fk_hosts_groups_on_groups FOREIGN KEY (group_id) REFERENCES hbi.groups(id);


--
-- Name: hosts_groups fk_hosts_groups_on_hosts; Type: FK CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE hbi.hosts_groups
    ADD CONSTRAINT fk_hosts_groups_on_hosts FOREIGN KEY (org_id, host_id) REFERENCES hbi.hosts(org_id, id) ON DELETE CASCADE;


--
-- Name: system_profiles_dynamic fk_system_profiles_dynamic_hosts; Type: FK CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE hbi.system_profiles_dynamic
    ADD CONSTRAINT fk_system_profiles_dynamic_hosts FOREIGN KEY (org_id, host_id) REFERENCES hbi.hosts(org_id, id) ON DELETE CASCADE;


--
-- Name: system_profiles_static fk_system_profiles_static_hosts; Type: FK CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE hbi.system_profiles_static
    ADD CONSTRAINT fk_system_profiles_static_hosts FOREIGN KEY (org_id, host_id) REFERENCES hbi.hosts(org_id, id) ON DELETE CASCADE;


--
-- Name: hosts_groups_old hosts_groups_host_id_fkey; Type: FK CONSTRAINT; Schema: hbi; Owner: Vf8S7GalvGVmaHGx
--

ALTER TABLE ONLY hbi.hosts_groups_old
    ADD CONSTRAINT hosts_groups_host_id_fkey FOREIGN KEY (host_id) REFERENCES hbi.hosts_old(id);


--
-- PostgreSQL database dump complete
--

\unrestrict 91gEmHJc7icrkLJUKUh3MElaSBwipOLoRNjc9lvxn6aHVlRJ7YC6Uab8LBy4yV2

