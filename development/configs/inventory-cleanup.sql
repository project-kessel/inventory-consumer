BEGIN;
DELETE FROM public.reporter_representations rr USING public.reporter_resources r WHERE rr.reporter_resource_id = r.id AND r.resource_type = 'host';
DELETE FROM public.common_representations where reported_by_reporter_type = 'hbi';
DELETE FROM public.reporter_resources where resource_type = 'host';
DELETE FROM public.resource where type = 'host';
COMMIT;
