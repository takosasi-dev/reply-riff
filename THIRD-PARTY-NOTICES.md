# 第三者の素材

同梱している第三者の素材は、次の字体 2 つだけです。音は `tools/gen_audio.py` で合成した自作の物です。

## Noto Sans JP(画面の字)

- ファイル: `assets/fonts/NotoSansJP-Subset.ttf`(原本を、画面に出す文字だけに絞った物。`tools/subset_font.py` で作る)
- 原本: https://github.com/google/fonts/tree/main/ofl/notosansjp の `NotoSansJP[wght].ttf`(コミット `295d98a7a0c17c68f1341eaeea354e7960ea70d3`)
- 原本の SHA-256: `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`
- ライセンス: SIL Open Font License, Version 1.1。原文は [`assets/fonts/OFL_NotoSansJP.txt`](assets/fonts/OFL_NotoSansJP.txt)(入手元の `OFL.txt` をそのまま置いた)
- 著作権表示: Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'

## Shrikhand(題字と数字。v0.3.0 から)

- ファイル: `assets/fonts/Shrikhand-Subset.ttf`(原本を、題字「ReplyRiff」と数字・記号の 24 字だけに絞った物。`tools/subset_font.py` で作る)。読み込み中の画面(`export_presets.cfg` の `html/head_include`)には「ReplyRif」の 8 字に絞った物を WOFF2 で埋め込んでいる
- 原本: https://github.com/google/fonts/tree/main/ofl/shrikhand の `Shrikhand-Regular.ttf`(コミット `295d98a7a0c17c68f1341eaeea354e7960ea70d3`)
- 原本の SHA-256: `8ba32f6d6a96fb8dbc92fc1acfbc4d2123d5348063d89b2c3dd784e7afcb81af`
- ライセンス: SIL Open Font License, Version 1.1。原文は [`assets/fonts/OFL_Shrikhand.txt`](assets/fonts/OFL_Shrikhand.txt)(入手元の `OFL.txt` をそのまま置いた)
- 著作権表示: Copyright (c) 2015 Jonny Pinhorn(Reserved Font Name は無い)

## 音

- ファイル: `assets/audio/*.wav`(15 個)と `assets/audio/mix/*.wav`(5 個。書き出しには入れない控え)
- 出どころ: `tools/gen_audio.py` で合成した自作の音。第三者の素材や既存の曲は使っていない。伴奏の和音の並び(C・Am・F・G)はよくある進行で、特定の曲から写した物ではない。ライセンスはリポジトリと同じ MIT。
