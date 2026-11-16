import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import path from "node:path";
import { Readable } from "node:stream";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  // On Vercel, redirect to the static Edge CDN asset in /downloads/ to avoid Serverless 4.5 MB body caps
  if (process.env.VERCEL) {
    return Response.redirect(
      new URL("/downloads/akkaraphon-toolkit.apk", request.url),
      307
    );
  }

  const apkPath = path.join(
    process.cwd(),
    "public",
    "downloads",
    "akkaraphon-toolkit.apk"
  );

  try {
    const fileStat = await stat(apkPath);
    const nodeStream = createReadStream(apkPath);
    const webStream = Readable.toWeb(nodeStream) as ReadableStream;

    return new Response(webStream, {
      status: 200,
      headers: {
        "Content-Type": "application/vnd.android.package-archive",
        "Content-Disposition": 'attachment; filename="akkaraphon-toolkit.apk"',
        "Content-Length": String(fileStat.size),
        "Cache-Control": "no-store, max-age=0",
      },
    });
  } catch {
    return Response.json(
      { error: "ไม่พบไฟล์ติดตั้ง akkaraphon-toolkit.apk บนเซิร์ฟเวอร์" },
      { status: 404 }
    );
  }
}
