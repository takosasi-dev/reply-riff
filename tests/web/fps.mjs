// プレイ中のフレームの間と、伴奏の時計のずれを測る(窓なし Chrome は描画がソフトなので、GPU の重さではなく「前の版と比べて重くなっていないか」の目安)。
//     node tests/web/fps.mjs [書き出しのフォルダ(既定 build/web)]
// 練習を始め、bot で 8 回とも弾き返しながら最後まで(約 60 秒)。その間の requestAnimationFrame の間と、
// 曲の位置 − AudioContext の時刻の差が始め(120 点)と終わり(120 点)でどれだけ動いたか(check.mjs の R-4 の目安と同じ式)を出す。
import { spawn } from 'node:child_process';
import { mkdtempSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { open, ROOT, sleep } from './lib.mjs';

const KEYS = ['a', 's', 'd', 'f', 'j', 'k', 'l', ';'];
const BAR = 288, EIGHTH = 36;
const replyStart = (t) => BAR + 2 * BAR * t + BAR;
const web = path.resolve(process.argv[2] || path.join(ROOT, 'build', 'web'));
const root = mkdtempSync(path.join(tmpdir(), 'rr-fps-'));
symlinkSync(web, path.join(root, 'reply-riff'), 'junction');
const server = spawn(process.env.RR_PYTHON || 'python', ['-m', 'http.server', '8818', '--bind', '127.0.0.1', '--directory', root], { stdio: 'ignore' });
await sleep(800);
const page = await open('http://127.0.0.1:8818/reply-riff/?debug=1', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });

async function reply(t) {
	const s = await page.waitState((st) => st.play && st.play.tick >= replyStart(t) - 60 && st.play.tick < replyStart(t), 20000);
	if (!s) return;
	const ph = s.play.phrase[t];
	const c = { tick: s.play.tick, at: Date.now() };
	for (let i = 0; i < ph.pos.length; i++) {
		const ms = c.at + ((replyStart(t) + ph.pos[i] * EIGHTH - c.tick) * 1000) / 120 - Date.now();
		if (ms > 0) await sleep(ms);
		page.down(KEYS[ph.keys[i]]);
		setTimeout(() => page.up(KEYS[ph.keys[i]]), 90);
	}
}

try {
	await page.waitState((s) => s.screen === 'gate', 30000);
	await page.key('x');
	await page.waitState((s) => s.screen === 'title');
	await sleep(500);
	await page.key('ArrowDown');
	await page.key('Enter');
	await page.waitState((s) => s.screen === 'play');
	await page.evaluate(`window.__gaps = []; (() => { let last = performance.now(); const f = (now) => { window.__gaps.push(now - last); last = now; requestAnimationFrame(f); }; requestAnimationFrame(f); })()`);
	for (let t = 0; t < 8; t++) await reply(t);
	await page.waitState((s) => s.play && s.play.over, 30000);
	await sleep(1200);
	const gaps = JSON.parse(await page.evaluate('JSON.stringify(window.__gaps)'));
	const log = JSON.parse((await page.evaluate('window.rrClock')) || '[]').filter((p) => p[1] > 0);
	const diff = log.map(([a, b]) => (a - b) * 1000);
	const q = (a, p) => [...a].sort((x, y) => x - y)[Math.min(a.length - 1, Math.floor(a.length * p))];
	const span = log.length ? log.at(-1)[0] - log[0][0] : 0;
	console.log(`${path.basename(web)}: ${(gaps.length / (gaps.reduce((s, g) => s + g, 0) / 1000)).toFixed(1)} fps / フレームの間 中央 ${q(gaps, 0.5).toFixed(1)}・95% ${q(gaps, 0.95).toFixed(1)}・99% ${q(gaps, 0.99).toFixed(1)}・最大 ${Math.max(...gaps).toFixed(1)} ms` +
		` / ${span.toFixed(1)} 秒で時計の差が ${(q(diff.slice(-120), 0.5) - q(diff.slice(0, 120), 0.5)).toFixed(1)} ms 動いた(${log.length} 点)`);
} finally {
	await page.close();
	server.kill();
	rmSync(path.join(root, 'reply-riff'), { force: true });
	rmSync(root, { recursive: true, force: true });
}
