// Supabase Edge Function: cleanup-consultation-files
// Automatically deletes files older than 20 days from 'chav_consultation_files' under 'consultation-files/'
// Project: CHAV (Organization: Shalini_Org)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RETENTION_DAYS = 20;
const BUCKET_NAME = "chav_consultation_files";
const FOLDER_PATH = "consultation-files";

Deno.serve(async (req: Request) => {
  // Allow manual invocation or scheduled cron trigger
  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    if (!supabaseUrl || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables." }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Compute cutoff timestamp: files created before this date are expired
    const cutoffTimestamp = new Date(Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000);
    console.log(`Running retention cleanup for bucket "${BUCKET_NAME}/${FOLDER_PATH}". Cutoff date (20 days ago): ${cutoffTimestamp.toISOString()}`);

    // Fetch files in bucket folder
    const { data: files, error: listError } = await supabase.storage
      .from(BUCKET_NAME)
      .list(FOLDER_PATH, {
        limit: 1000,
        sortBy: { column: "created_at", order: "asc" },
      });

    if (listError) {
      console.error("Failed to list files:", listError);
      return new Response(
        JSON.stringify({ error: listError.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // Filter files older than 20 days
    const expiredFiles = (files || []).filter((file) => {
      if (!file.created_at) return false;
      const fileDate = new Date(file.created_at);
      return fileDate < cutoffTimestamp;
    });

    if (expiredFiles.length === 0) {
      console.log("No expired files found.");
      return new Response(
        JSON.stringify({
          status: "success",
          message: "No files found exceeding 20-day retention limit.",
          deleted_count: 0,
        }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // Prepare paths for deletion
    const filePathsToDelete = expiredFiles.map((file) => `${FOLDER_PATH}/${file.name}`);
    console.log(`Deleting ${filePathsToDelete.length} expired files:`, filePathsToDelete);

    const { data: removeData, error: removeError } = await supabase.storage
      .from(BUCKET_NAME)
      .remove(filePathsToDelete);

    if (removeError) {
      console.error("Failed to remove expired files:", removeError);
      return new Response(
        JSON.stringify({ error: removeError.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({
        status: "success",
        message: `Successfully purged ${filePathsToDelete.length} files older than 20 days.`,
        deleted_count: filePathsToDelete.length,
        deleted_files: filePathsToDelete,
        executed_at: new Date().toISOString(),
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("Unexpected error in cleanup function:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
