-- ==============================================================================
-- MIGRATION: Ensure 1-to-1 Idempotency for Trip Proof of Visit
-- Target Table: public.trip_proofs
-- Constraint: UNIQUE (trip_id)
-- ==============================================================================
-- Menjamin secara atomik di level database bahwa 1 trip hanya dapat memiliki
-- tepat 1 record bukti kunjungan (Proof of Visit). Mencegah race condition
-- dan pembuatan proof ganda pada lingkungan serverless multi-instance.
-- ==============================================================================

DO $$
BEGIN
    -- 1. Pembersihan aman (deduplikasi data lama jika pernah ada duplikasi selama tahap testing)
    -- Mempertahankan record dengan prioritas: 'confirmed' > 'pending' > id terbaru
    IF EXISTS (
        SELECT trip_id FROM public.trip_proofs 
        GROUP BY trip_id HAVING COUNT(*) > 1
    ) THEN
        DELETE FROM public.trip_proofs
        WHERE id NOT IN (
            SELECT DISTINCT ON (trip_id) id
            FROM public.trip_proofs
            ORDER BY trip_id, 
                     CASE WHEN status = 'confirmed' THEN 1 
                          WHEN status = 'pending' THEN 2 
                          ELSE 3 END, 
                     id DESC
        );
    END IF;

    -- 2. Tambahkan UNIQUE constraint jika belum ada
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'trip_proofs_trip_id_key'
    ) THEN
        ALTER TABLE public.trip_proofs ADD CONSTRAINT trip_proofs_trip_id_key UNIQUE (trip_id);
    END IF;
END $$;
