# backend_v2 课表逻辑改动教程

这份教程记录 Docker 后端 `backend_v2` 的教务课表加载逻辑，方便下次继续改。

## 整体流程

用户登录或刷新课表时：

1. FastAPI 业务层调用 `HUEConnector.fetch_schedule(...)`。
2. 连接器先完成教务系统登录。
3. 登录成功后，优先请求默认完整课表：
   `GET /jsxsd/xskb/xskb_list.do`
4. 如果默认接口请求失败、状态码不是 200，或解析出的课程为空，再走备用接口。
5. 备用接口按第 1-20 周逐周请求，并合并课程。

## 主要文件

连接器主逻辑：

- `backend_v2/app/modules/connectors/hue_connector.py`
- 重点类：`HUEConnector`
- 重点函数：
  - `_fetch_schedule_once(...)`
  - `_fetch_default_schedule(...)`
  - `_fetch_fallback_schedule(...)`
  - `_merge_course_weeks(...)`

HTML 解析：

- `backend_v2/app/modules/connectors/hue_parser.py`
- 重点函数：
  - `parse_schedule_html(html)`
  - `parse_weeks(week_str)`

配置：

- `backend_v2/app/core/settings.py`
- 重点配置：
  - `academic_semester_start_date`

默认值是 `2026-03-02`，部署时可以用环境变量 `ACADEMIC_SEMESTER_START_DATE` 覆盖。

测试：

- `backend_v2/tests/test_hue_connector.py`

## 默认课表接口

默认课表请求保持为：

```python
session.get(
    f"{self.base_url}/jsxsd/xskb/xskb_list.do",
    timeout=10,
)
```

不要再传这些指定学期参数：

```python
data={
    "xnxq01id": "2025-2026-1",
    "sfFD": "1",
    "zc": "",
}
```

这样由教务系统自己返回当前默认完整课表，不需要维护 `COURSE_TERM_ID`。

## 备用接口

备用接口是：

```text
POST /jsxsd/framework/main_index_loadkb.jsp
body: rq=YYYY-MM-DD
```

`rq` 不是只查当天，而是返回这个日期所在周的一整周课表。

当前默认只查第 1-20 周：

```python
FALLBACK_WEEK_COUNT = 20
```

第 N 周请求日期计算方式：

```python
request_date = semester_start_date + timedelta(days=(week - 1) * 7)
```

## 合并规则

备用接口会逐周返回课程，所以需要合并。同一门课的合并 key 是：

```text
name
code
teacher
weekday
lesson_start
lesson_end
```

`room` 不参与合并。这样同一门课同一节次但不同周换教室时，会合并成一条，并把教室拼起来，例如：

```text
S101, S102
```

周次会合并成：

```text
1-2(周)
```

## 下次修改建议

如果要改默认接口，先改：

- `test_connector_uses_default_schedule_endpoint`

如果要改备用接口，先改：

- `test_connector_falls_back_to_weekly_endpoint_when_default_schedule_is_empty`

如果要改默认备用周数，先改：

- `test_connector_fallback_checks_twenty_weeks_by_default`

先让测试失败，再改 `backend_v2/app/modules/connectors/hue_connector.py`。
