// GingerBooks: create, reset and remove view-only guest logins. Only the books owner can call it.
import { createClient } from "npm:@supabase/supabase-js@2";
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const j = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, "Content-Type": "application/json" } });
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
    const tok = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
    const { data: ud, error: ue } = await admin.auth.getUser(tok);
    const user = ud?.user;
    if (ue || !user) return j({ error: "Please sign in to cloud sync first." }, 401);
    const { data: own } = await admin.from("books").select("user_id").eq("user_id", user.id).maybeSingle();
    if (!own) return j({ error: "Only the main account can manage guests." }, 403);
    const b = await req.json();
    if (b.action === "create" || b.action === "reset") {
      const email = String(b.email || "").trim().toLowerCase();
      const pw = String(b.password || "");
      if (!/^\S+@\S+\.\S+$/.test(email) || pw.length < 8) return j({ error: "A valid email and an 8+ character password are needed." }, 400);
      const { data: list } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
      const ex = list?.users?.find((u) => (u.email || "").toLowerCase() === email);
      let gid: string;
      if (ex) {
        if (ex.id === user.id) return j({ error: "That is your own account." }, 400);
        const { data: hb } = await admin.from("books").select("user_id").eq("user_id", ex.id).maybeSingle();
        if (hb) return j({ error: "That email belongs to a main account and cannot be a guest." }, 400);
        const { error } = await admin.auth.admin.updateUserById(ex.id, { password: pw, email_confirm: true });
        if (error) return j({ error: error.message }, 400);
        gid = ex.id;
      } else {
        if (b.action === "reset") return j({ error: "Guest not found." }, 404);
        const { data: c, error } = await admin.auth.admin.createUser({ email, password: pw, email_confirm: true, user_metadata: { role: "guest" } });
        if (error) return j({ error: error.message }, 400);
        gid = c.user!.id;
      }
      const row: Record<string, unknown> = { owner: user.id, guest: gid, email, name: b.name || null };
      if (b.action === "create") row.expires_at = new Date(Date.now() + Math.min(Math.max(parseInt(b.days) || 30, 1), 366) * 864e5).toISOString();
      if (b.fyFrom !== undefined) { row.fy_from = b.fyFrom || null; row.fy_to = b.fyTo || null; }
      const { error: e2 } = await admin.from("book_guests").upsert(row, { onConflict: "owner,guest" });
      if (e2) return j({ error: e2.message }, 400);
      return j({ ok: true, guest: gid });
    }
    if (b.action === "delete") {
      const { data: g } = await admin.from("book_guests").select("guest").eq("owner", user.id).eq("id", b.id).maybeSingle();
      if (!g) return j({ error: "Guest not found." }, 404);
      await admin.from("book_guests").delete().eq("id", b.id);
      const { data: others } = await admin.from("book_guests").select("id").eq("guest", g.guest);
      if (!others || !others.length) await admin.auth.admin.deleteUser(g.guest);
      return j({ ok: true });
    }
    return j({ error: "Unknown action." }, 400);
  } catch (e) {
    return j({ error: String((e as Error)?.message || e) }, 500);
  }
});
