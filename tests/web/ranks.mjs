// 段位の看板を段ごとに撮る(v0.3.1)。窓なし・消音・使い捨てのプロフィールの Chrome(lib.mjs)。
//     node tests/web/ranks.mjs [after]   → build/web_shots/after/s3_rank_<段>_*.png
// 練習で回 1〜k を弾き返し、後は押さない。全部ぴったりなら k = 8 → 18,100(いちばん上・新しい記録)、5 → 10,600、7 → 15,500。
// 路上(0 点)と前座(4,000 点・新しい記録)は shots.mjs の s3_result・s3_result2 が撮る。
import { mkdirSync } from 'node:fs';
import path from 'node:path';
import { open, OUT, serve, sleep } from './lib.mjs';

const DIR = path.join(OUT, process.argv[2] || 'after');
mkdirSync(DIR, { recursive: true });
const KEYS = ['a', 's', 'd', 'f', 'j', 'k', 'l', ';'];
const BAR = 288, EIGHTH = 36;
const replyStart = (t) => BAR + 2 * BAR * t + BAR;
const site = serve();
const page = await open(site.url + '?debug=1', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
const metrics = (w, h) => page.cdp.send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: w < 600 });
const one = (label) => page.shot(path.join(path.relative(OUT, DIR), label));

async function reply(t) {
	const s = await page.waitState((st) => st.play && st.play.tick >= replyStart(t) - 60 && st.play.tick < replyStart(t), 20000);
	if (!s) return false;
	const ph = s.play.phrase[t];
	const c = { tick: s.play.tick, at: Date.now() };
	for (let i = 0; i < ph.pos.length; i++) {
		const ms = c.at + ((replyStart(t) + ph.pos[i] * EIGHTH - c.tick) * 1000) / 120 - Date.now();
		if (ms > 0) await sleep(ms);
		page.down(KEYS[ph.keys[i]]);
		setTimeout(() => page.up(KEYS[ph.keys[i]]), 90);
	}
	return true;
}

async function run(k, label, sizes) {
	await page.waitState((s) => s.screen === 'play', 5000);
	for (let t = 0; t < k; t++) await reply(t);
	// 8 回とも判定した後(自分の曲の間)は Enter で飛ばす
	// (回 8 の判定の直後はまだ飛ばせないことがあるので、結果になるまで押し直す)
	const s = await page.waitState((st) => st.screen === 'result' || (st.play && st.play.judged >= 8), 60000);
	for (let i = 0; s && i < 60 && (await page.state()).screen !== 'result'; i++) {
		await page.key('Enter');
		await sleep(500);
	}
	const r = await page.waitState((st) => st.screen === 'result', 10000);
	const pts = r?.share?.split('\n')[1];
	console.log(`k=${k}: 段 ${r?.rank} / ${pts}`);
	if (k === 8) {
		await sleep(900);  // 吊り下がって電球を灯している途中
		await one(`s3_rank_mid_1280x720`);
	}
	await sleep(3600);  // 動きが終わるまで(判子 1240 ms + 紙吹雪 1800 ms)
	for (const [w, h] of sizes) {
		await metrics(w, h);
		await sleep(350);
		await one(`s3_rank_${label}_${w}x${h}`);
	}
	await metrics(1280, 720);
	await sleep(200);
}

const t0 = Date.now();
try {
	await page.waitState((s) => s.screen === 'gate', 30000);
	await page.key('x');
	await page.waitState((s) => s.screen === 'title');
	await sleep(400);
	await page.key('ArrowDown');
	await page.key('Enter');
	await run(8, 'top', [[1280, 720], [1920, 1080], [1024, 768], [2560, 1080], [390, 844]]);
	await page.key('r');
	await run(5, 'k5', [[1280, 720]]);
	await page.key('r');
	await run(7, 'k7', [[1280, 720]]);
	const errs = page.errors();
	console.log(`コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).slice(0, 5).join(' / ') : ''));
} catch (e) {
	console.log(`途中で止まった: ${e.stack ?? e}`);
} finally {
	await page.close();
	site.stop();
}
console.log(`撮った: ${DIR}(${Math.round((Date.now() - t0) / 1000)} 秒)`);
