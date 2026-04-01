-- Utilitaire pour les politiques RLS sur `events` : un événement `visibility = 'private'`
-- doit être lisible par tout utilisateur qui est responsable d’au moins une association
-- (pas seulement celle de l’événement), en plus des admins.
--
-- Exemple de condition USING (à fusionner avec ta politique existante) :
--   OR (visibility = 'private' AND (
--        EXISTS (SELECT 1 FROM public.users u WHERE u.id = auth.uid() AND u.role = 'admin')
--        OR public.is_responsible_anywhere(auth.uid())
--      ))

CREATE OR REPLACE FUNCTION public.is_responsible_anywhere(p_uid uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.user_id = p_uid
      AND m.role = 'responsible'
  );
$$;

REVOKE ALL ON FUNCTION public.is_responsible_anywhere(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_responsible_anywhere(uuid) TO authenticated;
