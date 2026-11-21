// Web 版をまとめて確かめ、画面を撮る(Chrome 1 回の起動で済ませる): 起動の時間・S0→S1→S4→S2→S5→S3→もう1回(AC-18)・
// 8 キーが本物のキー(CDP の Input.dispatchKeyEvent)で届いて弾き返せるか・タブが裏で一時停止(E-9)・保存と ParryDuel の保存の共存(AC-21)・
// 読み込み後の通信 0 件(AC-21)・揺れ 切(AC-20)・R-4 の目安(曲の位置とブラウザの AudioContext の時刻が 60 秒でずれないか)。
// 弾き返すのは JS の bot(?debug=1 の window.rrState のフレーズを読み、押す時刻を壁の時計で決める)。5 分ほどかかる。
//     node tests/web/check.mjs            手元の build/web を配って確かめる
//     RR_URL=https://…/reply-riff/ node tests/web/check.mjs --quick   公開した物を確かめる(練習の 60 秒の通しと負けの回を省く)
//     node tests/web/check.mjs --docs     README の画像を docs/ に写す
import { copyFileSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { expect, failureCount, open, OUT, ROOT, serve, sleep } from './lib.mjs';

const QUICK = process.argv.includes('--quick');
const KEYS = ['a', 's', 'd', 'f', 'j', 'k', 'l', ';'];
const BAR = 288, EIGHTH = 36, SONG_START = 4896, COUNT = 0, CALL = 1, REPLY = 2, SONG = 3;
const callStart = (t) => BAR + 2 * BAR * t;
const replyStart = (t) => callStart(t) + BAR;
const site = serve();
const page = await open(site.url + '?debug=1', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
const shot = (label) => page.shot(label);
const play = async () => (await page.state()).play;
const tap = (k, holdMs = 90) => { page.down(KEYS[k]); setTimeout(() => page.up(KEYS[k]), holdMs); };

// 曲の tick を壁の時計に直す(状態は 1 フレームぶん古いが、全部の音に同じだけ効くので間隔は崩れない)
async function clock() {
	const p = await play();
	return { tick: p.tick, at: Date.now() };
}
// タイトルで i 番目(0 今日の曲・1 練習・2 設定)を ↓ で選んで Enter(タイトルは前に選んだボタンを覚えている)
async function choose(i) {
	const s = await page.waitState((st) => st.screen === 'title' && st.sel !== undefined, 5000);
	for (let n = (i - s.sel + 3) % 3; n > 0; n--) await page.key('ArrowDown');
	await page.key('Enter');
}
const waitTick = async (c, tick) => { const ms = c.at + ((tick - c.tick) * 1000) / 120 - Date.now(); if (ms > 0) await sleep(ms); };

// 回 t を弾き返す。how: 'ok'(お手本どおり)/ 'wrong'(2 音目のキーを 1 つずらす)/ 'late'(3 音目を 15 tick 遅らせる = おしい)。
// shots: { reply: ラベル(最後の音の後、判定の前)、judged: ラベル(判定の直後) }
async function reply(t, how = 'ok', shots = {}) {
	const s = await page.waitState((st) => st.play && st.play.tick >= replyStart(t) - 60 && st.play.tick < replyStart(t), 20000);
	if (!s) return false;
	const ph = s.play.phrase[t];
	const c = { tick: s.play.tick, at: Date.now() };
	for (let i = 0; i < ph.pos.length; i++) {
		let k = ph.keys[i];
		if (how === 'wrong' && i === 1) k = k === 7 ? 6 : k + 1;
		await waitTick(c, replyStart(t) + ph.pos[i] * EIGHTH + (how === 'late' && i === 2 ? 15 : 0));
		tap(k);
		if (shots.mid && i === 1) { await sleep(40); await shot(shots.mid); }
	}
	if (shots.reply) { await sleep(60); await shot(shots.reply); }
	if (shots.judged) {
		const j = await page.waitState((st) => st.play && st.play.judged > t, 3000);
		await sleep(250);
		await shot(shots.judged);
		return j;
	}
	return true;
}

try {
	expect(page.booted, `起動した(Godot の印字まで ${page.bootMs} ms)`);
	const s0 = await page.waitState((s) => s.screen === 'gate', 30000);
	expect(!!s0, `S0 が出る(ページを開いてから ${Date.now() - page.t0} ms。NFR-6)`);
	const loadedAt = Date.now();
	await page.evaluate(`localStorage.setItem('parry-duel/save', '{"version":1,"keep":"me"}')`);
	await sleep(300);
	await shot('s0');
	await page.touch(...(await page.gameCss(640, 360)));
	await sleep(600);
	expect((await page.state()).screen === 'gate', 'タッチでは始まらない(FR-26)');
	await shot('s0_touch');
	await page.key('x');
	expect(!!(await page.waitState((s) => s.screen === 'title')), 'キーで S1');
	expect((await page.state()).unlocked, 'S0 の入力で音が鳴らせるようになる(FR-23)');
	await sleep(300);
	await shot('s1_title_first');
	// 試し弾き: 両手の 2 キーを同時に押さえる(本物のキーボードの同時押しではない)
	const n0 = (await page.state()).notes;
	await page.down('f');
	await page.down('j');
	await sleep(120);
	await shot('s1_title_strip');
	await page.up('f');
	await page.up('j');
	const t1 = await page.state();
	expect(t1.notes - n0 === 2 && t1.screen === 'title', `タイトルで F と J を同時に押すと 2 音鳴る(${t1.notes - n0} 音)`);
	// 16:9 でない窓: 余りは背景色で、舞台は真ん中
	await page.cdp.send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 900, deviceScaleFactor: 1, mobile: false });
	await sleep(400);
	await shot('s1_title_tall');
	await page.cdp.send('Emulation.setDeviceMetricsOverride', { width: 1500, height: 720, deviceScaleFactor: 1, mobile: false });
	await sleep(400);
	await shot('s1_title_wide');
	await page.cdp.send('Emulation.setDeviceMetricsOverride', { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
	await sleep(300);

	// S4 設定(↓↓ Enter)→ Esc で戻ると、設定のボタンが選ばれたまま
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'settings')), '↓↓ Enter で設定');
	await page.key('ArrowRight'); // 音量 75 → 100
	await sleep(200);
	await shot('s4_settings');
	await page.key('ArrowLeft');
	await page.key('Escape');
	expect(!!(await page.waitState((s) => s.screen === 'title' && s.sel === 2)), 'Esc でタイトルへ(設定のボタンが選ばれたまま)');

	// 今日の曲: 数え → 回 1(手がかりの光)→ 返す → 合った。回 3 はわざとキーを違えて外す。回 4 の返しの途中で一時停止
	await page.key('ArrowDown'); // 設定 → 今日の曲(一回りする)
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'play')), '↓ Enter で今日の曲');
	await page.waitState((s) => s.play && s.play.tick >= 150, 5000);
	await shot('s2_count');
	const lit = await page.waitState((s) => s.play && s.play.section === CALL && s.play.lit.length > 0, 8000);
	expect(lit && lit.play.lit[0] === 3, `回 1 のお手本で F の鍵が光る(lit ${JSON.stringify(lit?.play.lit)})`);
	await page.waitState((s) => s.play && s.play.call_pos.length >= 3, 3000);
	await shot('s2_call');
	const j0 = await reply(0, 'ok', { mid: 's2_reply', reply: 's2_reply_done', judged: 's2_turn_ok' });
	expect(j0?.play.layers === 1 && j0?.play.lives === 3, `回 1 を本物のキーで返すと合う(層 ${j0?.play.layers}、印 ${JSON.stringify(j0?.play.marks)})`);
	await page.waitState((s) => s.play && s.play.tick >= callStart(1) + 30, 5000);
	await sleep(100);
	await shot('s2_layer1');
	const j1 = await reply(1, 'late', { judged: 's2_turn_late' });
	expect(j1?.play.layers === 2, `回 2 で 3 音目を 125 ms 遅らせると、おしいで合う(印 ${JSON.stringify(j1?.play.marks)})`);
	const j2 = await reply(2, 'wrong', { reply: 's2_wrong_reply', judged: 's2_turn_miss' });
	expect(j2?.play.lives === 2 && j2?.play.layers === 2, `回 3 でキーを違えると外れ(残機 ${j2?.play.lives}、印 ${JSON.stringify(j2?.play.marks)})`);

	// 一時停止: 回 4 の返しの途中で Esc。止まっている間は tick が進まず、続けると回 4 のお手本の 1 小節前から(D-13)
	await page.waitState((s) => s.play && s.play.tick >= replyStart(3) + 100, 8000);
	await page.key('Escape');
	expect(!!(await page.waitState((s) => s.paused, 3000)), 'Esc で一時停止');
	await sleep(300);
	await shot('s5_pause');
	const tk0 = (await play()).tick;
	await sleep(1000);
	expect((await play()).tick === tk0, '一時停止の間、曲と sim が止まる(AC-19)');
	await page.key('ArrowDown');
	await page.key('ArrowDown');
	await page.key('Enter');
	expect(!!(await page.waitState((s) => s.screen === 'settings', 3000)), '一時停止から設定');
	await shot('s4_settings_from_pause');
	await page.key('Escape');
	expect(!!(await page.waitState((s) => s.screen === 'play' && s.paused, 3000)), '設定の戻るで一時停止へ');
	await page.key('Escape');
	const rs = await page.waitState((s) => !s.paused, 3000);
	expect(rs && rs.play.tick >= callStart(3) - BAR && rs.play.tick < callStart(3), `続けると回 4 のお手本の 1 小節前から(tick ${rs?.play.tick})`);
	await sleep(200);
	await shot('s2_resumed');
	// タブが裏に回る → 一時停止。戻っても自動では再開しない
	await page.hide();
	await sleep(800);
	await page.show();
	expect(!!(await page.waitState((s) => s.paused, 5000)), 'タブが裏に回ると一時停止(E-9)');
	const tk1 = (await play()).tick;
	await sleep(800);
	expect((await play()).tick === tk1, '戻っても自動では再開しない');
	await page.key('Escape');

	await reply(3, 'ok', { judged: 's2_turn4_ok' });
	await reply(4, 'ok');
	const c6 = await page.waitState((s) => s.play && s.play.section === CALL && s.play.turn === 5 && s.play.call_pos.length >= 2, 8000);
	expect(c6 && c6.play.lit.length === 0, '回 6 のお手本は 2 音目から光らない');
	await shot('s2_call6');
	await reply(5, 'ok');
	await reply(6, 'ok', { reply: 's2_reply7' });
	const j7 = await reply(7, 'ok', { judged: 's2_turn8_ok' });
	expect(j7?.play.layers === 4 && j7?.play.lives === 2, `回 8 まで返すと層 4・残機 2(層 ${j7?.play.layers})`);
	await page.waitState((s) => s.play && s.play.section === SONG && s.play.tick >= SONG_START + 120, 5000);
	await shot('s2_song');
	await page.waitState((s) => s.play && s.play.tick >= SONG_START + 2 * BAR + 100, 8000);
	await shot('s2_song_missbar');
	await page.key('Enter');
	const res = await page.waitState((s) => s.screen === 'result', 5000);
	expect(!!res, '自分の曲の間に Enter で結果へ(FR-25)');
	await sleep(400);
	await shot('s3_counting');
	await sleep(700);
	await shot('s3_result');
	expect(res?.share?.includes('(今日の曲・1回目)') && res?.share?.includes('8 小節 / 外れ 1 回'), `共有する文字: ${JSON.stringify(res?.share)}`);
	const saved = await page.saved();
	expect(saved?.daily?.first != null, `今日の曲の 1 回目が reply-riff/save に入る: ${JSON.stringify(saved)}`);
	expect((await page.evaluate(`localStorage.getItem('parry-duel/save')`)) === '{"version":1,"keep":"me"}', 'ParryDuel の保存を消さない(AC-21)');
	await page.evaluate(`navigator.clipboard.writeText('').catch(() => {})`);
	await page.clickButton('copy');
	await sleep(500);
	const cb = await page.clipboard();
	expect(cb.startsWith('ReplyRiff '), `コピーのボタン: ${JSON.stringify(cb).slice(0, 80)}`);
	await shot('s3_copied');

	// もう1回(R)→ 何も押さずに残機 0 で止まる
	await page.key('r');
	expect(!!(await page.waitState((s) => s.screen === 'play', 3000)), 'もう1回(R)');
	if (!QUICK) {
		const stop = await page.waitState((s) => s.play && s.play.over, 25000);
		await sleep(150);
		await shot('s2_over_stop');
		expect(stop?.play.lives === 0, '何も押さないと 3 回目で止まる');
		const r2 = await page.waitState((s) => s.screen === 'result', 3000);
		expect(r2?.share?.includes('(今日の曲)') && r2?.share?.includes('3 回目で止まった'), `2 回目: ${JSON.stringify(r2?.share)}`);
		await sleep(900);
		await shot('s3_result_stop');
	} else {
		await page.key('Escape');
		await page.waitState((s) => s.paused, 3000);
	}
	await page.clickButton('title');
	expect(!!(await page.waitState((s) => s.screen === 'title', 3000)), 'タイトルへ(マウス)');
	await sleep(300);
	await shot('s1_title_record');

	// 練習を一時停止なしで 60 秒通す(R-4 の目安)。最後の曲も飛ばさずに聞く
	if (!QUICK) {
		await choose(1);
		await page.waitState((s) => s.screen === 'play', 3000);
		for (let t = 0; t < 8; t++) await reply(t, 'ok');
		const fin = await page.waitState((s) => s.play && s.play.over, 30000);
		await sleep(100);
		await shot('s2_over_done');
		expect(fin?.play.layers === 4 && fin?.play.judged === 8, '練習を 8 回とも返して最後まで');
		const log = JSON.parse((await page.evaluate('window.rrClock')) || '[]').filter((p) => p[1] > 0);
		if (log.length > 200) {
			const diff = log.map(([song, ctx]) => (song - ctx) * 1000);
			const med = (a) => [...a].sort((x, y) => x - y)[Math.floor(a.length / 2)];
			const head = med(diff.slice(0, 120)), tail = med(diff.slice(-120));
			const span = log.at(-1)[0] - log[0][0];
			const jitter = diff.map((d) => Math.abs(d - med(diff))).sort((x, y) => x - y)[Math.floor(diff.length * 0.95)];
			expect(span >= 55, `伴奏の時計を 55 秒以上見た(${span.toFixed(1)} 秒)`);
			expect(Math.abs(tail - head) < 20, `R-4 の目安: 伴奏の時計(曲の位置)と AudioContext の時刻の差が ${span.toFixed(1)} 秒で ${(tail - head).toFixed(1)} ms 動いた(20 ms 未満。ゆらぎの 95% 値 ${jitter.toFixed(1)} ms、${log.length} 点。4 層どうしのずれは見ていない)`);
			writeFileSync(path.join(OUT, 'clock.json'), JSON.stringify(log));
		} else expect(false, `AudioContext の時刻が読めない(${log.length} 点)`);
		const r3 = await page.waitState((s) => s.screen === 'result', 3000);
		expect(r3?.share?.includes('(練習)') && r3?.share?.includes('外れ 0 回'), `練習は 8 回とも合った: ${JSON.stringify(r3?.share)}`);
		await sleep(900);
		await shot('s3_result_newbest');
		await page.clickButton('title');
		await page.waitState((s) => s.screen === 'title', 3000);
	}

	// 揺れ 切・点滅を弱める 入 で外す(AC-20)
	await choose(2);
	await page.waitState((s) => s.screen === 'settings', 3000);
	await page.key('ArrowDown');
	await page.key('Enter');
	await page.key('ArrowDown');
	await page.key('Enter');
	await sleep(200);
	await shot('s4_settings_changed');
	const st = (await page.saved())?.settings;
	expect(st?.shake === false && st?.reduce_flash === true, `設定が保存に入る: ${JSON.stringify(st)}`);
	await page.key('Escape');
	await choose(1);
	await page.waitState((s) => s.screen === 'play', 3000);
	await page.waitState((s) => s.play && s.play.section === CALL && s.play.lit.length > 0, 8000);
	await shot('s2_call_reduced');
	await reply(0, 'wrong');
	let moved = false;
	await page.waitState((s) => s.play && s.play.judged >= 1, 3000);
	for (let j = 0; j < 10; j++) {
		if ((await play()).pos.some((v) => v !== 0)) moved = true;
		if (j === 1) await shot('s2_miss_reduced');
		await sleep(15);
	}
	expect(!moved, '揺れを切ると外しても画面が動かない(AC-20)');

	const after = page.requests.filter((r) => r.at > loadedAt);
	expect(after.length === 0, `読み込みの後の通信 ${after.length} 件(${Math.round((Date.now() - loadedAt) / 1000)} 秒見た)` + (after.length ? ': ' + after.map((r) => r.url).join(', ') : ''));
	console.log('    転送した大きさ: ' + JSON.stringify(page.sizes()));
	console.log('    出力の遅れ(Godot が読んだ値): ' + (await page.state()).music.latency);

	// キーの確かめの画面(?keys=1)。8 キーと G・H を押す
	const base = page.url0.split('?')[0];
	expect(await page.goto(base + '?keys=1&debug=1'), 'キーの確かめの画面を開き直す');
	await page.waitState((s) => s.screen === 'gate', 20000);
	await page.key('x');
	expect(!!(await page.waitState((s) => s.screen === 'keys', 3000)), '?keys=1 でキーの確かめの画面');
	for (const c of [...KEYS, 'g', 'h']) { await page.key(c); await sleep(30); }
	await shot('keys');
	if (process.argv.includes('--docs')) {
		mkdirSync(path.join(ROOT, 'docs'), { recursive: true });
		for (const [f, to] of [['s1_title_record', 'title'], ['s2_turn4_ok', 'play'], ['s3_result_newbest', 'result']]) copyFileSync(path.join(OUT, f + '.png'), path.join(ROOT, 'docs', to + '.png'));
	}
} catch (e) {
	expect(false, `途中で止まった: ${e.stack ?? e}`);
} finally {
	const errs = page.errors();
	expect(errs.length === 0, `コンソールのエラー ${errs.length} 件` + (errs.length ? ': ' + errs.map((e) => e.text).slice(0, 5).join(' / ') : ''));
	await page.close();
	site.stop();
}
console.log(failureCount() === 0 ? '全部 OK' : `${failureCount()} 件 NG`);
process.exit(failureCount() === 0 ? 0 : 1);
