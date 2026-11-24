// First login for an invited employee. Creates their login only if HR invited that email.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { email, password } = await req.json();
    const e = String(email ?? "").trim().toLowerCase();
    if (!e || String(password ?? "").length < 8) return json({ error: "Kata sandi minimal 8 karakter." });
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const { data: inv } = await admin.from("invites").select("id,status").eq("email", e).limit(1).maybeSingle();
    if (!inv) return json({ error: "Email ini belum diundang. Hubungi HR perusahaan Anda." });
    if (inv.status === "active") return json({ error: "Akun ini sudah aktif. Silakan masuk." });
    const { error } = await admin.auth.admin.createUser({ email: e, password, email_confirm: true });
    if (error) return json({ error: error.message.includes("already") ? "Akun ini sudah aktif. Silakan masuk." : error.message });
    return json({ ok: true });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
