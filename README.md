# GoM Attachment Workbench

Project Zomboid **B42.20.4**용 독립형 총기 개조 작업대. Mod ID: `GoMAttachmentWorkbench`.

**상태: 0.1 테스트 빌드. 소스/설치본 검증과 실제 게임 검증은 별개입니다.**
필수 모드: 현재 `GunsOfMarz` 및 해당 모드의 의존성 `SWMG` (Gunworks Framework).
구형 `MarzGuns` 및 다른 총기 모드는 지원하지 않습니다. GoM이 활성화된 경우에만 바닐라 총기를 지원합니다.

## 사용

1. 모드 선택에서 GoM과 이 모드를 활성화하고 게임을 완전히 재시작합니다.
2. 지원 총기를 우클릭 → **총기 개조 작업대 열기**.
3. 왼쪽 아이콘 목록에서 총기를 선택합니다. 가운데 슬롯 카드의 화살표를 누르면 맨 오른쪽에 해당 슬롯의 호환 부품이 표시됩니다.
4. 오른쪽 부품을 클릭하여 장착을 예약합니다. 재클릭하거나 현재 장착품을 선택하면 해당 교체를 취소합니다. 카드의 큰 아이콘은 **현재 장착품**, 작은 금색 표시 아이콘은 **장착 예정품**입니다.
5. 아래 작업 목록에서 자동 추가된 레일/마운트와 교체 반환 항목을 확인하고 **조립 시작**을 누릅니다. 총기와 부품을 소지품으로 옮긴 뒤, 바닐라/GoM의 도구 장착·부품 제거·무기 개선 작업을 순서대로 수행합니다.

- 소지품, 같은 층의 자기 타일 및 인접 8타일의 접근 가능한 바닥·가구·차량 보관함을 검색합니다.
- 벽, 잠금, 차량 접근 제한, 멀티플레이 안전가옥 약탈 제한을 검사합니다.
- 가방 안도 검색하되 최대 8단계입니다. 도구는 **플레이어 소지품 안**에 있어야 합니다.
- 보유한 호환 부품을 먼저 표시하며 없는 호환 부품은 아이콘과 글씨를 회색으로 표시합니다. 선택한 총기의 지원 슬롯만 카드로 나열합니다. 긴 설명은 마우스를 올려 확인합니다.
- 한 번에 총기 하나만 개조합니다. 주변 총기와 선택 부품은 일반 아이템 이동 작업으로 플레이어 소지품에 가져옵니다.
- 범용 피카티니 레일은 실제 아이템 하나당 슬롯 하나에만 사용합니다. 교체한 범용 마운트는 Gunworks 규칙대로 범용 아이템으로 반환합니다.
- 시작 전에는 부품·접근 경로·장착 상태를 다시 확인합니다. 작업 도중 조건이 바뀌면 남은 작업을 중단합니다. 각 이동과 조립의 실제 처리는 게임의 기본 서버 작업 경로를 사용합니다.
- **Esc 취소는 남은 작업만 중단합니다.** 이미 옮긴 아이템과 완료한 조립은 유지되며 이전처럼 전체를 원상복구하지 않습니다. 진행 중에는 새 조립을 중복 등록하지 않습니다.
- **하부 총열 모드가 활성화된 총기, 탄약 상태를 보유할 수 있는 하부 총열 제거/교체는 안전상 거절**합니다. 이 경우 기존 GoM 메뉴를 사용해야 합니다. 일반 부착물·레일 교체는 지원합니다.

## 설치 / 검증

```powershell
./scripts/test.ps1
./scripts/test-installed.ps1
./scripts/install-local.ps1
```

`test.ps1`은 기존 JDK로 작은 테스트 실행기를 컴파일하고 **설치된 게임의 Kahlua VM**으로 Lua 테스트와 구문 검사를 수행합니다. 새 npm/Python 의존성을 설치하지 않습니다. 경로는 스크립트 매개변수로 변경할 수 있습니다.

UI 수정본은 B42의 `Translate/EN/IG_UI.json` 및 `Translate/KO/IG_UI.json`을 사용합니다. 이전의 잘못된 `IGUI_LANG.txt` 파일은 제거했습니다. 테스트는 게임의 실제 JSON 번역 로더로 두 언어를 읽고, UI 모형에서 아이콘 그리기·슬롯 선택·회색 표시·장착 예약 동작을 검사합니다. 실제 게임 스크린샷 검증을 대신하지는 않습니다.

`test-installed.ps1`은 Workshop 원본을 읽기만 하며 6개 대표 총기, 범용 레일, 실제 의존성/도구 레지스트리를 검사합니다. 추출 데이터와 해시는 무시되는 `evidence/`에만 생성되며 배포 모드에 포함되지 않습니다.

`install-local.ps1`은 `~/Zomboid/mods/GoMAttachmentWorkbench`에 설치합니다. 기존 설치본은 먼저 저장소 `evidence/backups/`에 백업하고 파일별 SHA-256을 검증합니다. 저장 게임, 서버 프리셋 및 Workshop 원본은 수정하지 않습니다.

## English

Right-click a supported firearm, open the workbench, select parts by slot, review the dependency-first cart, and apply once. Accessible nearby sources are scanned only on open/refresh. Tools must be in the player's recursive inventory. Work is scheduled through native inventory transfer, removal and upgrade actions, including their normal durations and GoM tool handling. The game owns authoritative action completion; the old custom instant-apply endpoint has been removed. Cancellation stops remaining actions, preserving completed transfers/upgrades just like vanilla. Replaced parts return to player inventory; universal rails follow Gunworks generic-item refund rules.

This is a **test build**, not an in-game-verified release. Stateful underbarrel removal/replacement is deliberately excluded to avoid ammunition loss. No upstream source or assets are bundled. See [verification](docs/verification.md) and [implementation decisions](docs/design.md).

## Workshop staging

```powershell
./scripts/prepare-workshop-assets.ps1
./scripts/stage-workshop.ps1
```

This creates `~/Zomboid/Workshop/GoMAttachmentWorkbench` with `workshop.txt`, a 256px Workshop preview, and the standalone package. After the first Steam upload assigns an ID, run `./scripts/set-workshop-id.ps1 -WorkshopId <id>` and stage again before updating the item. For a local B42.20.4 multiplayer test, run `./scripts/add-to-b42204-preset.ps1`; it adds the local mod immediately after `GunsOfMarz` without adding an unpublished ID to `WorkshopItems`.
