# 입사 지원 제출 증빙 자동 검사

최종 제출 버튼을 누르지 않고 마감을 넘기는 일을 막기 위한 장치입니다. 배경과 규칙은 `AGENTS.md` 행동 규칙 8번, 공고 폴더 절차는 `JD/README.md`를 보십시오.

## 0. 쓰기 전에 (선택 기능, Windows 전용)

- 이 폴더는 **선택 사항**입니다. 없어도 워크스페이스는 동작합니다. 체크리스트와 `AGENTS.md` 규칙만으로도 효과가 큽니다.
- 스크립트는 **Windows PowerShell 5.1 기준**입니다. Windows 작업 스케줄러 등록, 팝업 알림, Git 훅과 Claude Code 훅의 실행 명령(`powershell.exe`) 모두 Windows를 전제로 합니다. macOS나 Linux에서는 그대로 동작하지 않습니다.
- 쓰지 않기로 했다면 아래를 함께 지우십시오. 일부만 지우면 훅이 없는 스크립트를 찾으며 오류를 냅니다.

| 지울 것 | 이유 |
|---|---|
| `scripts/` 폴더 | 검사 스크립트와 설치 스크립트 |
| `.githooks/` 폴더 | 커밋할 때 검사 스크립트를 부르는 Git 훅 |
| `.claude/settings.json`의 `hooks` 부분 | Claude Code가 세션 시작과 메시지 전송 때 검사 스크립트를 부름. `permissions` 부분(제출본 폴더 보호)은 스크립트와 무관하므로 남겨 두는 것을 권함 |
| `AGENTS.md` 행동 규칙 8번의 '기계적 검사' 항목 | 다른 에이전트에게 스크립트 실행을 지시하는 문장 |

- 이미 이 PC에 설치(3절)했다면, 지우기 전에 먼저 3-3절의 제거 명령을 실행해 작업 스케줄러 등록과 Git 훅 연결을 해제하십시오.

## 1. 한눈에 보기

검사 스크립트는 `scripts/check-submission-proof.ps1` 하나입니다. 이 스크립트를 네 가지 경로로 실행합니다.

| 실행 경로 | 언제 실행되나 | 알림 방식 | 에이전트 종류와 무관한가 | 설치 |
|---|---|---|---|---|
| Windows 작업 스케줄러 | 매일 09, 13, 18, 21, 23시와 로그인할 때 | 팝업 창 | 예. 에이전트를 안 써도 실행됨 | PC마다 한 번 (3절) |
| Git 훅 | 커밋할 때마다 | 커밋 출력 아래 경고 | 예. 어떤 도구로 커밋하든 실행됨 | PC마다 한 번 (3절) |
| Claude Code 훅 | Claude Code 세션을 시작할 때, 메시지를 보낼 때마다 | 화면 경고 + 에이전트에게 전달 | Claude Code만 | 설치 필요 없음 (`.claude/settings.json`) |
| 직접 실행 | 원할 때 | 콘솔 출력 | 예 | 없음 |

검사 대상이 아니면 아무 알림도 뜨지 않습니다.

## 2. 무엇을 검사하나

`JD/` 바로 아래의 진행 중인 공고만 봅니다. `JD/Submitted/`, `JD/DEPRECATED/`는 보지 않습니다.

| 공고 상태 | 검사 결과 |
|---|---|
| 작성 중 (표식 없음) | 대상 아님 |
| 메인 문서 프론트매터에 `제출 대기: true` | **경고.** 마감이 가까울수록 문구가 강해짐(D-1, 오늘 마감, 마감 지남) |
| `단계`가 `지원 완료`인데 아직 `JD/` 바로 아래에 있음 | **경고.** 증빙 없이 지원 완료로 표시된 것 |
| 공고 폴더 `submitted/`에 이름에 `제출 완료 증빙`이 들어간 파일이 있음 | 통과 |
| 프론트매터 `증빙 면제:`에 사유가 있음 | 통과 (지원 완료 화면이 없는 사이트 등 예외용) |

공고 하나의 흐름:

1. 자기소개서와 지원 양식을 모두 검토하면 메인 문서에 `제출 대기: true`를 켭니다. 이때부터 알림이 시작됩니다.
2. 온라인 폼에서 **최종 제출**을 누릅니다.
3. 지원 완료 화면이나 접수 확인 이메일을 캡처해 `submitted/제출 완료 증빙.png`로 저장합니다(확장자 무관).
4. `제출 대기`를 지우고 `단계`를 `지원 완료`로 바꾼 뒤 폴더를 `JD/Submitted/YYYY-MM/`로 옮깁니다. 알림이 멈춥니다.

## 3. 이 PC에 설치하기 (처음 한 번)

다른 PC에서 레포를 새로 받았을 때도 같은 순서로 한 번 실행합니다.

### 3-1. 설치 명령

1. 시작 메뉴에서 **Windows PowerShell**을 엽니다. 관리자 권한은 필요 없습니다.
2. 레포 폴더로 이동합니다.
   ```powershell
   cd "C:\경로\내-워크스페이스"
   ```
3. 설치 스크립트를 실행합니다.
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/setup-this-pc.ps1
   ```
4. 아래 두 줄이 나오면 설치가 끝난 것입니다.
   ```
   [1/2] Git 훅 연결: core.hooksPath = .githooks
   [2/2] 작업 스케줄러 등록: 'career-workspace-submission-proof-check' (...)
   ```

Claude Code를 터미널에서 쓰고 있다면 이 명령을 프롬프트에 `! powershell -ExecutionPolicy Bypass -File scripts/setup-this-pc.ps1`처럼 앞에 `!`를 붙여 입력해도 됩니다.

### 3-2. 설치 확인

- **검사 스크립트**: `powershell -ExecutionPolicy Bypass -File scripts/check-submission-proof.ps1`
  - 문제가 없으면 `제출 증빙 검사: 문제 없음`이 나옵니다.
- **작업 스케줄러**: 시작 메뉴에서 **작업 스케줄러**를 열고, 왼쪽 **작업 스케줄러 라이브러리**를 누르면 목록에 `career-workspace-submission-proof-check`가 보입니다.
  - 지금 한 번 실행해 보려면: `Start-ScheduledTask -TaskName 'career-workspace-submission-proof-check'`
  - 검사 대상이 없으면 팝업이 뜨지 않는 것이 정상입니다.
- **Git 훅**: `git config --get core.hooksPath`를 실행하면 `.githooks`가 나옵니다.

### 3-3. 제거

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup-this-pc.ps1 -Uninstall
```

### 3-4. 알림 시각 바꾸기

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup-this-pc.ps1 -Times 10:00,20:00,23:30
```

## 4. 처음 쓰는 분을 위한 설명

### 4-1. Windows 작업 스케줄러

- Windows에 기본으로 들어 있는 "예약 실행" 기능입니다. 정해진 시각이나 로그인할 때 프로그램을 자동으로 실행합니다.
- **Claude와 완전히 별개**입니다. Claude, Cursor, Codex를 하나도 켜지 않아도 실행됩니다.
- 이 레포에서는 검사 스크립트를 실행하고, 증빙이 없는 공고가 있으면 **확인을 누를 때까지 화면 맨 위에 떠 있는 팝업**을 띄웁니다.
- 실행할 때 검은 창이 잠깐 깜빡일 수 있습니다. 정상입니다.
- 한계
  - PC가 꺼져 있으면 실행되지 않습니다. 대신 `StartWhenAvailable` 설정으로, 놓친 시각이 있으면 PC를 켰을 때 실행합니다.
  - 등록 정보는 PC마다 저장됩니다. 레포에 커밋되지 않으므로 PC마다 3절 설치를 한 번 해야 합니다.
  - 레포 폴더를 다른 곳으로 옮기면 설치를 다시 실행해야 합니다(스크립트의 절대 경로가 저장되기 때문).

### 4-2. Git 훅

- Git이 특정 동작(커밋, 푸시 등) 때 자동으로 실행하는 스크립트입니다.
- 이 레포는 **커밋을 마친 직후**(`post-commit`) 검사를 실행해, 문제가 있으면 커밋 출력 아래에 경고를 보여 줍니다. **커밋을 막지는 않습니다.**
- 어떤 도구로 커밋하든(터미널, VS Code, GitHub Desktop, 다른 회사의 AI 에이전트) Git이 실행하므로 도구와 무관합니다.
- Git 훅 파일은 원래 `.git/hooks/`에 두는데, 이 폴더는 레포에 커밋되지 않습니다. 그래서 커밋 가능한 `.githooks/`에 두고, `git config core.hooksPath .githooks`로 "이 폴더를 훅 폴더로 쓰라"고 알려 줍니다. 이 설정은 PC마다 저장되므로 3절 설치가 필요합니다.
- 일부 GUI 도구는 훅 출력을 잘 보여 주지 않을 수 있습니다. 그래서 Git 훅은 보조 장치이고, 주 알림은 작업 스케줄러입니다.

### 4-3. Claude Code 훅

- `.claude/settings.json`에 설정되어 있고 레포에 커밋되어 있어, 이 레포를 Claude Code로 열면 별도 설치 없이 동작합니다.
- 세션을 시작할 때와 메시지를 보낼 때마다 검사합니다. 문제가 있으면 화면에 경고가 뜨고, 같은 내용이 에이전트에게도 전달되어 에이전트가 응답에서 증빙을 요구합니다.
- 설정을 처음 추가한 세션에서는 바로 적용되지 않을 수 있습니다. Claude Code를 다시 시작하거나 `/hooks`를 한 번 열면 적용됩니다.
- 끄고 싶을 때는 `/hooks` 메뉴에서 확인하고 관리할 수 있습니다.

### 4-4. 다른 회사의 에이전트를 쓸 때

작업 스케줄러와 Git 훅은 에이전트와 무관하게 동작합니다. 그리고 `AGENTS.md` 행동 규칙 8번에 "작업 시작 시 검사 스크립트를 실행하라"는 지시가 있어, AGENTS.md를 읽는 에이전트(Codex, Cursor, Copilot 등)도 검사를 실행하게 됩니다. 다만 이 지시는 에이전트가 지키기를 기대하는 방식이라, 기계적으로 보장되는 것은 앞의 두 가지입니다.

## 5. 문제 해결

| 증상 | 확인할 것 |
|---|---|
| 팝업이 한 번도 안 뜸 | 검사 대상이 있는지 먼저 직접 실행으로 확인. 대상이 있는데 안 뜨면 작업 스케줄러에서 작업을 오른쪽 클릭 > 실행, "마지막 실행 결과" 확인 |
| 한글이 깨져 보임 | `check-submission-proof.ps1`이 UTF-8 **BOM 포함**으로 저장되어 있어야 함(Windows PowerShell 5.1 요구). 편집기로 고칠 때 인코딩 유지 |
| "스크립트를 실행할 수 없습니다" 오류 | 명령에 `-ExecutionPolicy Bypass`를 붙였는지 확인 |
| 커밋해도 경고가 안 뜸 | `git config --get core.hooksPath`가 `.githooks`인지 확인 |
