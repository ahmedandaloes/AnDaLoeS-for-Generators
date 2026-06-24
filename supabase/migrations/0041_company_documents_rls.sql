-- Audit: company_documents RLS
-- RLS is already enabled and three policies exist (SELECT owner+admin, INSERT owner, DELETE owner).
-- Gap: admins need UPDATE to mark documents as verified.

CREATE POLICY company_documents_admin_update ON public.company_documents
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());
