# API 接口规范 (API Specification)

**版本**: v1.0
**日期**: 2026-02-03
**协议**: HTTP/1.1 RESTful
**格式**: JSON
**鉴权**: Header `Authorization: Bearer <token>`

---

## 1. 认证模块 (Auth)

### 1.1 苹果登录/注册
*   **Path**: `POST /api/v1/auth/apple`
*   **Desc**: 验证 Apple Identity Token，如果用户不存在则自动注册。
*   **Req**:
    ```json
    {
      "identity_token": "eyJraWQi...",
      "first_name": "John", // 仅第一次登录有
      "last_name": "Appleseed"
    }
    ```
*   **Resp**:
    ```json
    {
      "access_token": "jwt_token_string",
      "token_type": "bearer",
      "user": { ...UserObject }
    }
    ```

---

## 2. 用户模块 (Users)

### 2.1 获取当前用户信息
*   **Path**: `GET /api/v1/users/me`
*   **Desc**: 获取自己详细资料（包含 created_at, phone 等隐私信息）。
*   **Resp**: `UserObject`

### 2.2 搜索/获取公开用户信息
*   **Path**: `GET /api/v1/users/{public_id_or_uuid}`
*   **Desc**: 查看他人资料（仅公开字段：昵称、头像、ID）。
*   **Resp**: `UserPublicObject`

### 2.3 更新个人资料
*   **Path**: `PUT /api/v1/users/me`
*   **Req**:
    ```json
    {
      "nickname": "新昵称",
      "avatar_url": "https://..."
    }
    ```

---

## 3. 队伍模块 (Teams)

### 3.1 创建队伍
*   **Path**: `POST /api/v1/teams`
*   **Req**:
    ```json
    {
      "name": "超级辩论队",
      "intro": "专治不服",
      "avatar_url": "..."
    }
    ```
*   **Resp**: `TeamObject`

### 3.2 获取我的队伍列表
*   **Path**: `GET /api/v1/users/me/teams`
*   **Desc**: 获取我参与的所有队伍（包括我创建的、管理的、加入的）。
*   **Resp**: `[TeamObject]`

### 3.3 获取队伍详情
*   **Path**: `GET /api/v1/teams/{team_id}`
*   **Desc**: 包含基础信息。如果我是成员，额外返回成员列表。
*   **Resp**: `TeamDetailObject`

### 3.4 邀请成员
*   **Path**: `POST /api/v1/teams/{team_id}/members`
*   **Auth**: 仅 Owner/Admin。
*   **Req**:
    ```json
    {
      "user_public_id": "U888888" // 通过公开 ID 邀请
    }
    ```

### 3.5 移除成员/退出队伍
*   **Path**: `DELETE /api/v1/teams/{team_id}/members/{user_id}`
*   **Auth**: 
    *   如果是自己 user_id -> 退出。
    *   如果是他人 user_id -> 踢人 (需权限)。

---

## 4. 赛事模块 (Tournaments)

### 4.1 创建赛事
*   **Path**: `POST /api/v1/tournaments`
*   **Req**:
    ```json
    {
      "name": "2026星火杯",
      "intro": "...",
      "cover_url": "..."
    }
    ```

### 4.2 获取赛事列表
*   **Path**: `GET /api/v1/tournaments`
*   **Query**: `?status=open` (报名中/进行中)
*   **Resp**: `[TournamentSummary]`

### 4.3 赛事报名 (Team Join)
*   **Path**: `POST /api/v1/tournaments/{tournament_id}/teams`
*   **Desc**: 队长提交报名申请。
*   **Req**:
    ```json
    {
      "team_id": "uuid-of-my-team"
    }
    ```

### 4.4 审核报名队伍
*   **Path**: `PUT /api/v1/tournaments/{tournament_id}/teams/{team_id}/status`
*   **Auth**: Tournament Admin。
*   **Req**:
    ```json
    {
      "status": "approved" // or "rejected"
    }
    ```

---

## 5. 赛程模块 (Matches)

### 5.1 创建赛程 (Create Match)
*   **Path**: `POST /api/v1/tournaments/{tournament_id}/matches`
*   **Auth**: Tournament Admin。
*   **Req**:
    ```json
    {
      "name": "初赛第一场",
      "start_time": "2026-02-15T14:00:00Z",
      "end_time": "2026-02-15T16:00:00Z",
      "format": "4v4",
      "team_a_id": "uuid-team-a",
      "team_b_id": "uuid-team-b",
      "location": "腾讯会议 123-456"
    }
    ```

### 5.2 指派上场名单 (Roster)
*   **Path**: `PUT /api/v1/matches/{match_id}/roster`
*   **Auth**: Team A 或 Team B 的 Owner/Admin。
*   **Req**:
    ```json
    {
      "team_id": "uuid-team-a", // 确认是哪个队提交的
      "assignments": [
        { "user_id": "uuid-u1", "position": "一辩" },
        { "user_id": "uuid-u2", "position": "二辩" },
        { "user_id": "uuid-u3", "position": "三辩" },
        { "user_id": "uuid-u4", "position": "四辩" }
      ]
    }
    ```

### 5.3 录入比赛结果
*   **Path**: `PUT /api/v1/matches/{match_id}/result`
*   **Auth**: Tournament Admin。
*   **Req**:
    ```json
    {
      "winner_team_id": "uuid-team-a",
      "score_meta": { "team_a_score": 9, "team_b_score": 0 }
    }
    ```

---

## 6. 日程模块 (Schedule)
*这是 App 首页“我的日程”的数据源。*

### 6.1 获取我的待办与赛程
*   **Path**: `GET /api/v1/users/me/schedule`
*   **Query**: `?from=2026-02-01&to=2026-03-01`
*   **Resp**:
    ```json
    {
      "matches_playing": [], // 我上场的
      "matches_team": [],    // 我队上场的（但我没上）
      "matches_managed": []  // 我管理的赛事中的待办场次
    }
    ```

