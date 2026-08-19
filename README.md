# XGC2 Field Panel

车上独立 Web 面板。和 XGC2 Core / Agent / Experiment 并行。

只做两件事：用 `roslaunch --wait` 启停进程；订/发官方 ROS 消息。不 Depend 底盘、估计器、NMPC、动捕。那些包没装时，点启动会报错。

感知（动捕 + `estimator_vrpn_ugv_state` 别名拉起 3D `Pose3InertialEskf`，订 `/imu/data`）和控制（参考 / NMPC / 摆渡）是两组启停。估计话题是 `RigidStateEstimate`，面板 compare 用投影后的 x/y/yaw；`estimator_state=3` 才算 RUNNING。先看 IMU、CAN、动捕、估计是否新鲜，再启控制。默认 `FIELD_PANEL_STATE_SOURCE=estimator`。VRPN 直通是错误旁路。

## Package

- Product id: `xgc2-field-panel`
- Debian: `xgc2-field-panel`
- ROS: `xgc2_field_panel`
- Source: `products/ros1/tools/field-panel`

```bash
sudo apt update
sudo apt install xgc2-field-panel
source /opt/ros/melodic/setup.bash
roslaunch xgc2_field_panel panel.launch port:=8099
```

浏览器：`http://<车上IP>:8099/`
