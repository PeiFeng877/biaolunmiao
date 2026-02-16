# 数据库设计详述 (Database Schema Detailed)

[PROTOCOL]: 变更时更新此头部，然后检查 GEMINI.md

**版本**: v1.1  
**日期**: 2026-02-03  
**数据库**: PostgreSQL  
**设计原则**: 全局包含审计字段 (时间戳) 与生命周期状态字段。

---

## 1. 通用字段定义 (Common Fields)
*所有表默认包含以下字段，后文表中不再重复列出，但默认存在。*

| 英文名称 | 中文名称 | 作用/备注 | 属性 (Type) | 范围/约束 | 必填 |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **id** | 主键 ID | 全局唯一的记录标识符 | UUID | Primary Key | ✅ |
| **created_at** | 创建时间 | 记录数据的产生时间 | Timestamp | - | ✅ |
| **updated_at** | 更新时间 | 记录数据的最后修改时间 | Timestamp | - | ✅ |
| **status** | 状态 | 记录实体的生命周期状态 | SmallInt | 见各表定义 | ✅ |

---

## 2. 用户表 (users)
**核心实体**。仅支持 Apple ID 登录。

| 英文名称 | 中文名称 | 作用/备注 | 属性 (Type) | 范围/约束 | 必填 |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **apple_sub** | 苹果用户标识 | Apple Sign-In 返回的唯一 ID (Subject)，用于鉴权 | Varchar(128) | Unique Index | ✅ |
| **public_id** | 公开 ID | 用于用户之间搜索、展示的短 ID | Varchar(20) | Unique, 字母+数字 | ✅ |
| **nickname** | 昵称 | 用户显示的名称 | Varchar(50) | - | ✅ |
| **avatar_url** | 头像地址 | 用户头像图片的存储路径 | Varchar(255) | URL | ❌ |
| **status** | 账号状态 | **0**: 正常 (Normal)<br>**1**: 注销 (Deleted)<br>**2**: 封禁 (Banned) | SmallInt | 0, 1, 2 | ✅ |

---

## 3. 队伍表 (teams)
**核心实体**。队伍是一个独立的组织单元。

| 英文名称 | 中文名称 | 作用/备注 | 属性 (Type) | 范围/约束 | 必填 |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **public_id** | 队伍公开 ID | 系统自动生成的数字 ID，用于搜索 | Varchar(20) | Unique Index | ✅ |
| **name** | 队伍名称 | 队伍的名字，允许重复 | Varchar(50) | - | ✅ |
| **owner_id** | 队长 ID | 关联到 users 表，标识谁拥有该队 | UUID | Foreign Key | ✅ |
| **intro** | 简介 | 队伍的简短介绍 | Text | Max 500 chars | ❌ |
| **avatar_url** | 队徽地址 | 队伍头像 | Varchar(255) | URL | ❌ |
| **status** | 队伍状态 | **0**: 正常 (Normal)<br>**1**: 解散 (Disbanded)<br>**2**: 封禁 (Banned) | SmallInt | 0, 1, 2 | ✅ |

---

## 4. 队伍成员关系表 (team_members)
**关系实体**。连接 User 和 Team，记录成员在队内的角色和状态。

| 英文名称 | 中文名称 | 作用/备注 | 属性 (Type) | 范围/约束 | 必填 |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **team_id** | 队伍 ID | 归属的队伍 | UUID | FK | ✅ |
| **user_id** | 用户 ID | 对应的成员 | UUID | FK | ✅ |
| **role** | 队内角色 | 决定操作权限 | SmallInt | **0**: 队员 (Member)<br>**1**: 管理员 (Admin)<br>**2**: 队长 (Owner) | ✅ |
| **join_time** | 加入时间 | 实际入队的时间点 | Timestamp | - | ✅ |
| **status** | 成员状态 | **0**: 在队 (Active)<br>**1**: 已退出 (Left)<br>**2**: 被踢出 (Kicked) | SmallInt | 0, 1, 2 | ✅ |

*注：(team_id, user_id) 需建立联合唯一索引，确保一个用户在一个队里只有一条记录。*

---

## 5. 赛事表 (tournaments)
**核心实体**。

| 英文名称 | 中文名称 | 作用/备注 | 属性 (Type) | 范围/约束 | 必填 |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **name** | 赛事名称 | 比如“2026星火杯” | Varchar(100) | - | ✅ |
| **creator_id** | 创建人 ID | 发起该赛事的用户 | UUID | FK | ✅ |
| **intro** | 赛事介绍 | 赛事的详细描述 | Text | - | ❌ |
| **cover_url** | 封面图 | 赛事的宣传图 | Varchar(255) | URL | ❌ |
| **start_date** | 开始日期 | 预计开始时间 | Date | - | ❌ |
| **end_date** | 结束日期 | 预计结束时间 | Date | - | ❌ |
| **status** | 赛事状态 | **0**: 报名中 (Open)<br>**1**: 进行中 (Ongoing)<br>**2**: 已结束 (Ended) | SmallInt | 0-2 | ✅ |

---

## 6. 赛事管理员表 (tournament_admins)
**关系实体**。记录谁拥有该赛事的管理权限。

| 英文名称 | 中文名称 | 作用/备注 | 属性 (Type) | 范围/约束 | 必填 |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **tournament_id** | 赛事 ID | - | UUID | FK | ✅ |
| **user_id** | 用户 ID | - | UUID | FK | ✅ |
| **role** | 权限角色 | **1**: 创建者 (Creator) - 拥有解散权、管理权、指派权<br>**2**: 管理员 (Admin) - 仅拥有管理权、录入权 | SmallInt | 1, 2 | ✅ |
| **status** | 状态 | **0**: 正常<br>**1**: 已移除 | SmallInt | 0, 1 | ✅ |

---

## 7. 赛程/比赛表 (matches)
**核心实体**。记录具体的每一场对决。

| 英文名称 | 中文名称 | 作用/备注 | 属性 (Type) | 范围/约束 | 必填 |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **tournament_id** | 赛事 ID | 所属赛事 | UUID | FK | ✅ |
| **name** | 场次名称 | 如“初赛第一场”、“半决赛” | Varchar(100) | - | ✅ |
| **team_a_id** | 正方/A队 | 关联 teams 表 | UUID | FK (Nullable) | ❌ |
| **team_b_id** | 反方/B队 | 关联 teams 表 | UUID | FK (Nullable) | ❌ |
| **start_time** | 开始时间 | 比赛具体时间点 | Timestamp | - | ✅ |
| **end_time** | 结束时间 | 预计结束时间 | Timestamp | - | ✅ |
| **location** | 地点/链接 | 线下教室或线上腾讯会议号 | Varchar(255) | - | ❌ |
| **format** | 赛制 | 决定几人上场 | Varchar(20) | 1v1, 2v2, 3v3, 4v4 | ✅ |
| **status** | 比赛状态 | **0**: 未开始 (Scheduled)<br>**1**: 进行中 (Ongoing)<br>**2**: 已结束 (Finished)<br>**3**: 取消 (Cancelled) | SmallInt | 0-3 | ✅ |

---

## 8. 比赛工作人员表 (match_staff)
**关系实体**。记录每场比赛的主席与评委。

| 英文名称 | 中文名称 | 作用/备注 | 属性 (Type) | 范围/约束 | 必填 |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **match_id** | 比赛 ID | - | UUID | FK | ✅ |
| **user_id** | 用户 ID | - | UUID | FK | ✅ |
| **role** | 工作角色 | **1**: 主席 (Chairperson)<br>**2**: 评委 (Judge) | SmallInt | 1, 2 | ✅ |
| **status** | 状态 | **0**: 正常<br>**1**: 移除/请假 | SmallInt | 0, 1 | ✅ |

---

## 9. 比赛指派表 (match_rosters)
**业务关键实体**。记录“谁”代表“哪个队”在“哪场比赛”打了“什么位置”。

| 英文名称 | 中文名称 | 作用/备注 | 属性 (Type) | 范围/约束 | 必填 |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **match_id** | 比赛 ID | - | UUID | FK | ✅ |
| **team_id** | 队伍 ID | 必须是该场比赛的 A 队或 B 队 | UUID | FK | ✅ |
| **user_id** | 队员 ID | 必须是该 team 的成员 | UUID | FK | ✅ |
| **position** | 辩位/位置 | 如“一辩”、“四辩” | Varchar(20) | - | ✅ |
| **status** | 指派状态 | **0**: 正常 (Confirmed)<br>**1**: 撤销 (Revoked) | SmallInt | 0, 1 | ✅ |
