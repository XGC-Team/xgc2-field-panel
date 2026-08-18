cmake_minimum_required(VERSION 3.0.2)
project(xgc2_field_panel)

find_package(catkin REQUIRED)
catkin_package()

catkin_install_python(PROGRAMS
  scripts/field_panel_node
  scripts/vrpn_to_planar_state
  DESTINATION ${CATKIN_PACKAGE_BIN_DESTINATION}
)

install(DIRECTORY launch web
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)
