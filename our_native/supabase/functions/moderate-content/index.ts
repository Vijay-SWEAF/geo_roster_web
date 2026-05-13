// Supabase Edge Function: moderate-content
// Uses OpenAI Moderation API (free endpoint) to screen posts and comments
// for hate speech, sexual content, violence, self-harm, and political harassment.
//
// POST body: { "text": "content to moderate" }
// Response:  { "flagged": bool, "reason": string | null, "categories": object }

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  try {
    const { text } = await req.json();

    if (!text || typeof text !== "string" || text.trim().length === 0) {
      return new Response(
        JSON.stringify({ flagged: false, reason: null, categories: {} }),
        { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const openAiKey = Deno.env.get("OPENAI_API_KEY");
    if (!openAiKey) {
      // If key not configured, allow content through (fail-open for availability)
      console.warn("OPENAI_API_KEY not set — skipping moderation");
      return new Response(
        JSON.stringify({ flagged: false, reason: null, categories: {} }),
        { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const response = await fetch("https://api.openai.com/v1/moderations", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${openAiKey}`,
      },
      body: JSON.stringify({ input: text.trim() }),
    });

    if (!response.ok) {
      const errText = await response.text();
      console.error("OpenAI moderation API error:", errText);
      // Fail-open: let admin review manually
      return new Response(
        JSON.stringify({ flagged: false, reason: null, categories: {} }),
        { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    const data = await response.json();
    const result = data.results?.[0];

    if (!result) {
      return new Response(
        JSON.stringify({ flagged: false, reason: null, categories: {} }),
        { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
      );
    }

    // Build human-readable reason from flagged categories
    let reason: string | null = null;
    if (result.flagged) {
      const flaggedCategories: string[] = Object.entries(result.categories)
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        .filter(([, v]: [string, any]) => v === true)
        .map(([k]) => _categoryLabel(k));

      reason = flaggedCategories.length > 0
        ? `Content flagged: ${flaggedCategories.join(", ")}.`
        : "Content flagged by safety system.";
    }

    return new Response(
      JSON.stringify({
        flagged: result.flagged,
        reason,
        categories: result.categories,
        category_scores: result.category_scores,
      }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("moderate-content error:", err);
    // Fail-open: don't block users if moderation service is down
    return new Response(
      JSON.stringify({ flagged: false, reason: null, categories: {} }),
      { headers: { ...CORS_HEADERS, "Content-Type": "application/json" } }
    );
  }
});

function _categoryLabel(key: string): string {
  const labels: Record<string, string> = {
    hate: "hate speech",
    "hate/threatening": "threatening hate speech",
    harassment: "harassment",
    "harassment/threatening": "threatening harassment",
    "self-harm": "self-harm",
    "self-harm/intent": "self-harm intent",
    "self-harm/instructions": "self-harm instructions",
    sexual: "sexual content",
    "sexual/minors": "sexual content involving minors",
    violence: "violent content",
    "violence/graphic": "graphic violence",
  };
  return labels[key] ?? key;
}
