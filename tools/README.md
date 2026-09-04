# 케이스 스터디 생성기

프로젝트 폴더 하나를 주면 포트폴리오에 케이스 스터디를 만들어 준다.

**이미 있는 케이스 스터디를 그대로 복사하는 방식이다.** 따로 템플릿을 두지 않는다.
템플릿을 쓰면 페이지가 늘어날수록 원본과 조금씩 어긋나고, 애널리틱스 스크립트나 폰트 링크처럼
눈에 안 보이는 것부터 빠진다. 복사하면 그럴 일이 없다.

- `<포트폴리오>/<슬러그>/index.html` — 참고 페이지 복사 + 제목·경로·히어로 문구만 교체
- `<포트폴리오>/<슬러그>/style.css` — 참고 페이지가 쓰는 CSS 를 이름 그대로
- `<포트폴리오>/index.html` — 프로젝트 카드 삽입 + 번호 재정렬

Windows에 기본으로 깔린 PowerShell만 쓴다. **설치할 것 없음.** Python도 Node도 필요 없다.

## 실행

가장 쉬운 방법은 `new-case.cmd` 에 프로젝트 폴더를 끌어다 놓는 것이다. 두 번 눌러 실행하면 경로를 물어본다.

```
new-case.cmd C:\work\my-api
```

PowerShell에서 직접 부를 수도 있다.

```powershell
.\New-CaseStudy.ps1 -Project C:\work\my-api
.\New-CaseStudy.ps1 -Project C:\work\my-api -Reference harness-refactor -Title "주문 정산 API"
.\New-CaseStudy.ps1 -Project C:\work\my-api -DryRun
```

만들고 나면 페이지를 열어 **본문을 새로 쓰면 된다.** 복사해 온 직후에는 참고한 프로젝트의 글이 그대로 들어 있다.

## 옵션

| 옵션 | 설명 | 안 주면 |
|---|---|---|
| `-Project` | 케이스 스터디로 만들 프로젝트 폴더 (필수) | — |
| `-Reference` | 본떠올 케이스 스터디 폴더명 | 가장 최근에 손댄 페이지 |
| `-Slug` | 포트폴리오 안에 만들 폴더명. URL이 된다 | 프로젝트 폴더명 |
| `-Title` | 페이지 제목 | 슬러그 |
| `-Summary` | 한 줄 소개 | README 첫 문단 |
| `-Period` | `2026.08 — 2026.09` | git 첫 커밋 ~ 마지막 커밋 |
| `-Repo` | GitHub 주소 | `git remote get-url origin` |
| `-Tags` | `-Tags Python,FastAPI,Docker` | 프로젝트 파일에서 추정 |
| `-PortfolioDir` | 포트폴리오 루트 | 이 스크립트의 상위 폴더 |
| `-DryRun` | 무엇을 할지만 출력하고 파일은 안 씀 | |
| `-Force` | 이미 있는 폴더에 덮어쓰기 (기존 페이지는 백업) | |

## 바꾸는 것과 두는 것

복사한 페이지에서 **네 곳만** 바꾼다.

| 자리 | 바뀌는 값 |
|---|---|
| `<title>` | `-Title` |
| 상단바 `brand-cur` | `-Slug` |
| 히어로 `h1` | `-Title` |
| 히어로 `hero-summary` | `-Summary` |

나머지는 손대지 않는다. 섹션 구성, 클래스 이름, 폰트·아이콘 링크, 애널리틱스 스크립트 모두 참고한 쪽과 같다.
CSS 는 `style.css` 인 페이지도 있고 `styles.css` 인 페이지도 있어서 **파일명을 그대로 복사한다.**
이름을 바꾸면 복사해 온 `<link>` 가 깨진다.

## 자동으로 읽는 것

git이 있으면 **기간**과 **저장소 주소**를 커밋 기록에서 가져온다. git이 없거나 저장소가 아니면 경고만 하고 `TODO` 로 남기니, 그때는 `-Period` 와 `-Repo` 를 직접 주면 된다.

**태그**는 프로젝트 안의 파일을 보고 짐작한다.

| 파일 | 붙는 태그 |
|---|---|
| `composer.json` | PHP, (laravel/framework 있으면) Laravel |
| `pyproject.toml` · `requirements.txt` | Python, FastAPI, Django, Celery, SQLAlchemy, LangChain, Playwright |
| `package.json` | TypeScript, Next.js, React |
| `Dockerfile` · `docker-compose.yml` | Docker |
| `.github/workflows` | GitHub Actions |
| `.claude` | Claude Code |

짐작이라 정확하지 않다. 마음에 안 들면 `-Tags` 로 덮어쓰거나 만들어진 HTML에서 고치면 된다.

**카드 위치**는 기간의 끝 연월을 보고 최신순으로 끼워 넣고, 나머지 카드 번호를 다시 매긴다.

## 다른 PC에서 쓰기

`tools/` 폴더를 포트폴리오 저장소에 같이 커밋해두면 된다. clone 받은 곳에서 바로 돌아간다.

```
git add tools
git commit -m "chore: 케이스 스터디 생성기 추가"
```

스크립트는 자기 위치(`tools/`)의 상위를 포트폴리오 루트로 본다. 다른 곳에 두고 쓰려면 `-PortfolioDir` 를 준다.

## 본문 쓸 때

기존 페이지들과 톤을 맞추려면:

- 규칙을 선언하지 말고 겪은 일을 먼저 쓴다 — "요약을 넘기지 않는다" 보다 "요약을 넘겼더니 줄 번호가 사라졌다"
- 항목마다 형식을 똑같이 맞추지 않는다. 문단 수도 태그 개수도 들쭉날쭉한 편이 자연스럽다
- 굵은 글씨는 페이지 전체에서 한두 곳만
- 잘 안 된 것도 적는다. 성공만 나열하면 안 읽힌다

## 알아둘 것

- `New-CaseStudy.ps1` 은 **UTF-8 BOM** 으로 저장돼 있다. Windows PowerShell 5.1이 BOM 없는 파일의 한글을 깨뜨리기 때문에, 편집한 뒤에도 BOM을 유지해야 한다.
- 생성되는 HTML은 BOM 없는 UTF-8 · CRLF다. 기존 페이지들과 같다.
- `-Force` 로 덮어쓸 때 기존 `index.html` 을 `index.html.<날짜>.bak` 로 백업한다. 써둔 글이 날아가지 않는다.
- 같은 프로젝트를 두 번 돌려도 루트 `index.html` 의 카드는 한 번만 들어간다. 이미 있으면 건너뛴다.
- GitHub Pages는 push 후 반영까지 시간이 좀 걸린다. 링크가 404면 잠시 기다렸다 다시 본다.
