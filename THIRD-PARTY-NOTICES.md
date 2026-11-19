# 第三者の素材

同梱している第三者の素材は、次の字体 1 つだけです。音は `tools/gen_audio.py` で合成した自作の物です。

## Noto Sans JP(画面の字)

- ファイル: `assets/fonts/NotoSansJP-Subset.ttf`(原本を、画面に出す文字だけに絞った物。`tools/subset_font.py` で作る)
- 原本: https://github.com/google/fonts/tree/main/ofl/notosansjp の `NotoSansJP[wght].ttf`(コミット `295d98a7a0c17c68f1341eaeea354e7960ea70d3`)
- 原本の SHA-256: `c2f3b4d463500a2ddcd3849cded1fceeb9fd6d1c32e6cbecd568453ba50fc68f`
- ライセンス: SIL Open Font License, Version 1.1。原文は [`assets/fonts/OFL_NotoSansJP.txt`](assets/fonts/OFL_NotoSansJP.txt)(入手元の `OFL.txt` をそのまま置いた)
- 著作権表示: Copyright 2014-2021 Adobe (http://www.adobe.com/), with Reserved Font Name 'Source'

## 音

- ファイル: `assets/audio/*.wav`(15 個)と `assets/audio/mix/*.wav`(5 個。書き出しには入れない控え)
- 出どころ: `tools/gen_audio.py` で合成した自作の音。第三者の素材や既存の曲は使っていない。伴奏の和音の並び(C・Am・F・G)はよくある進行で、特定の曲から写した物ではない。ライセンスはリポジトリと同じ MIT。
