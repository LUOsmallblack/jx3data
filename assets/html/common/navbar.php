<?php
function isactive($title) {
  return $GLOBALS["myTitle"] == $title ? "active" : "";
}
?>
<nav class="navbar navbar-expand-lg navbar-light bg-light">
  <a class="navbar-brand" href="#">Jx3App</a>

  <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarContent" aria-controls="navbarContent" aria-expanded="false" aria-label="Toggle navigation">
    <span class="navbar-toggler-icon"></span>
  </button>

  <div class="collapse navbar-collapse" id="navbarContent">
    <ul class="navbar-nav mr-auto">
      <li class="nav-item <?= isactive("home") ?>">
        <a class="nav-link" href="index.html">Home</a>
      </li>

      <li class="nav-item <?= isactive("about") ?>">
        <a class="nav-link" href="about.html">About</a>
      </li>
    </ul>
  </div>
</nav>