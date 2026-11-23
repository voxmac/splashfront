# SPLASH FRONT — 로블록스 페인트 FPS

게임 소스와 에셋 제작 파이프라인을 한 저장소에서 관리합니다. 에셋은 다른 채널·프로젝트와 같은 방식으로 만듭니다.

| 에셋 | 만드는 방법 | 결과 |
| --- | --- | --- |
| 맵별 배경음악 5곡 | **Kaggle 무료 T4 + ACE-Step 1.5**(MIT, 상업 이용 가능) — MIDLIFE COMMUTER 채널과 같은 설정 | `assets/audio/*.ogg` (루프 편집 완료) |
| 상황별 효과음 37개 | numpy 합성, 샘플 없음 — 채널 `sfx.py`와 같은 방식 | `assets/sfx/*.ogg` + 한 파일 아틀라스 |
| 총 6종 + 헬멧·백팩 | Blender(bpy) 절차 모델링 — 모이믄 GLB 생성기와 같은 방식 | `assets/models/*.fbx` + 미리보기 |

```
bgm/SF01.json ──(bgm 워크플로)──▶ Kaggle T4 ──▶ 루프 편집 ──▶ assets/audio ──┐
tools/make_sfx.py ─────────────────────────────────────────▶ assets/sfx ────┤
tools/make_models.py ──────────────────────────────────────▶ assets/models ─┤
                                                                            ▼
                         roblox-upload 워크플로 (Open Cloud) ──▶ asset ID ──▶ game/src/shared/AssetIds.lua
                                                                            ▼
                                                     game/SplashFront.rbxlx 자동 재빌드
```

## 폴더
- `game/` 게임 소스(Rojo 프로젝트) + `SplashFront.rbxlx`(Studio에서 바로 여는 파일)
- `bgm/` 배경음악 작업 파일 · `assets/` 만들어진 음악·효과음·모델 · `tools/` 제작·업로드 스크립트

## 처음 한 번만: 비밀값 (Settings → Secrets and variables → Actions)
| Name | 값 | 용도 |
| --- | --- | --- |
| `KAGGLE_USERNAME`, `KAGGLE_KEY` | midlifecommuter와 같은 값 | 배경음악 생성 |
| `ROBLOX_API_KEY` | create.roblox.com → Open Cloud → API Keys → **Assets API: Read, Write** (IP 제한 0.0.0.0/0) | 업로드 |
| `ROBLOX_CREATOR` | `user:내 UserId` (게임을 그룹이 소유하면 `group:그룹Id`) | 업로드 소유자 |

> 소유자가 게임 소유자와 같아야 음악·모델이 게임에서 재생·로드됩니다.

## 실행 순서
1. **배경음악**: `bgm/SF01.json`을 커밋하면 자동 실행됩니다(Actions → bgm). 끝나면 "BGM ready" 이슈가 메일로 오고, 업로드 비밀값이 있으면 **roblox-upload**가 이어서 실행됩니다.
2. **효과음·모델**: 이미 만들어져 있습니다. 다시 만들 때는 `python tools/make_sfx.py assets/sfx`, `python tools/make_models.py assets/models`(pip install bpy).
3. **업로드**: Actions → roblox-upload → Run workflow (`all`). 바뀐 파일만 올리고 `AssetIds.lua`와 `SplashFront.rbxlx`를 커밋합니다.
4. Studio에서 `game/SplashFront.rbxlx`를 엽니다.

업로드 전에도 게임은 그대로 돌아갑니다. 효과음은 Studio 기본음, 총·장비는 파트로 조립한 대체 모델, 배경음악은 무음입니다.

## 오디오 업로드 한도
로블록스 오디오 업로드는 30일에 신원 인증 계정 100개, 미인증 계정 10개로 제한됩니다. 효과음 37개를 **아틀라스 1개 파일**로 묶어 올리므로 배경음악 5 + 효과음 1 = **6개**만 씁니다. 게임은 `Sound.PlaybackRegion`으로 필요한 구간만 재생합니다.

## Studio에서 직접 모델 넣기 (업로드 대신)
Studio → Avatar/Home → **Import 3D** → `assets/models/*.fbx` → 단위 **Stud** → 가져온 모델 이름을 `Gun_Pistol`처럼 파일 이름과 같게 두고 `ReplicatedStorage/SplashModels` 폴더(없으면 만들기)에 넣습니다. 파트 이름 끝 `_Body/_Accent/_Metal/_Anchor/_Muzzle`는 그대로 둡니다.

## 배경음악 다른 테이크 고르기
"BGM ready" 이슈에서 모든 테이크를 들을 수 있습니다. `bgm/SF01.json`에 `"pick": {"chroma": 2}`를 넣고 Actions → bgm → Run workflow(`collect_only = true`)로 GPU 없이 다시 편집합니다.

## Kaggle 사용량
곡 5개 × 테이크 2~3개 = 13테이크. 설치 약 15분 + 테이크당 2~4분 → 약 1~1.5 GPU시간.
