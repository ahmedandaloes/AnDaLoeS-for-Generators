-- KYC v1: wire company_documents table for admin review workflow.
--
-- 1. Add verified column: admin sets true once the document is cleared.
-- 2. Add unique constraint on (company_id, doc_type) so upsert works correctly
--    (one active document per type per company).

ALTER TABLE public.company_documents
  ADD COLUMN IF NOT EXISTS verified boolean NOT NULL DEFAULT false;

ALTER TABLE public.company_documents
  DROP CONSTRAINT IF EXISTS company_documents_company_doc_type_key;

ALTER TABLE public.company_documents
  ADD CONSTRAINT company_documents_company_doc_type_key
  UNIQUE (company_id, doc_type);
