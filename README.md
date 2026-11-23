# SPLASH FRONT — 로블록스 페인트 FPS

게임 소스(Rojo)와 에셋 제작 파이프라인. 배경음악은 MIDLIFE COMMUTER 채널과 같은 방식으로 **Kaggle 무료 T4 + ACE-Step 1.5(MIT, 상업 이용 가능)** 로 만듭니다.

```
bgm/SF01.json 커밋 (또는 Actions → bgm → Run workflow)
        │  GitHub Actions: bgm
        ▼
Kaggle T4 (무료): 곡마다 여러 테이크 생성
        │
        ▼
이 저장소의 러너(CPU): 테이크 자동 선택 → 4마디 단위 루프 편집 → 음량 맞춤
        │
        ▼
assets/audio/*.ogg 커밋 + 모든 테이크 Release + "BGM ready" 이슈(메일 알림)
```

## 처음 한 번만: 비밀값 등록
저장소 **Settings → Secrets and variables → Actions → New repository secret**

| Name | Value |
| --- | --- |
| `KAGGLE_USERNAME` | voxmac/midlifecommuter에 넣은 값과 같음 |
| `KAGGLE_KEY` | voxmac/midlifecommuter에 넣은 값과 같음 |

**Settings → Actions → General → Workflow permissions**는 **Read and write permissions**로 둡니다.
등록 후 **Actions → bgm → Run workflow → id = SF01** 로 실행합니다.

## 곡 목록 (bgm/SF01.json)
| 트랙 | 쓰임 | 길이 |
| --- | --- | --- |
| lobby | 로비 | 루프 |
| chroma | 크로마 스퀘어 경기 | 루프 |
| sky | 스카이 루프탑 경기 | 루프 |
| victory | 승리 결과 | 징글 |
| defeat | 패배 결과 | 징글 |

다른 테이크로 바꾸려면 작업 파일에 `"pick": {"chroma": 2}`를 넣고 **Run workflow (collect_only = true)** 로 GPU 없이 다시 편집합니다.

## Kaggle 사용량
곡 5개 × 테이크 2~3개 = 13테이크. 설치 15분 + 테이크당 약 2~4분, 합계 약 1~1.5 GPU시간.
