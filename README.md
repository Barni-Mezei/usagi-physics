This is a simple constraint solver 2D physics engine

Made with the [Usagi](https://github.com/brettchalupa/usagi) engine

# Running the  game

Download Usagi and then you can run the program like so `./usagi run`

# General controls

- `space`: To pause or unpause the simulation
- `A/D` or `Left/Right`: To switch tools
- `1` ... `9`: To load blueprints (1: rectangle, 2: polygon, 3: rope)
- `LMB`: Use selected tool
- `LMB`: Use selected tool (secondary mode)


# Tools

- ## Ball placer

  #### Description

  This tool allows you to place balls (nodes) in the world. Each ball has a radius and a mass.

  #### Controls
  - Left click to place a ball
  - Right click on a ball to delete it



- ## Selection tool

  #### Description
  
  This tool allows you to select balls for further action
  
  #### Controls
  - Left click and drag: area selection
  - Right click on a ball: Select the whole creation this ball is connected to



- ## Move tool

  #### Description
  
  This tool allows you to move the selected balls
  
  #### Controls
  - Left click and drag: MOve balls (even in simulated mode)
  - Right click and drag: Teleport balls on release



- ## Pin tool

  #### Description

  With this tool, you can fix balls in place

  #### Controls
  - Left click on a ball: Pin ball to at current position
  - Right click on a ball: Remove pinning



- ## Animation tool [WIP]

  #### Description
  
  This tool allows you to add fix animations to a ball. (Like rotation, or mouse following)
  
  #### Controls
  - Left click on a ball: Add selected animation
  - Right click on a ball: Remove selected animation



- ## Connect tool

  #### Description
  
  This tool allows you to create connections (distance constraints) between balls
  
  #### Controls
  - Left click on a ball: Start creating a connection, left click on a ball to finish it
  - Right click on a connection: Delete
