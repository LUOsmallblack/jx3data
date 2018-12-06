<?php
function isactive($title) {
  return $GLOBALS["myTitle"] == $title ? "active" : "";
}
?>
<nav class="navbar sticky-top navbar-expand-lg navbar-light bg-light">
  <div class="container">
    <a class="navbar-brand" href="#">Jx3App</a>

    <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarContent" aria-controls="navbarContent" aria-expanded="false" aria-label="Toggle navigation">
      <span class="navbar-toggler-icon"></span>
    </button>

    <div class="collapse navbar-collapse" id="navbarContent">

      <form class="form-inline my-2 my-lg-0" action="search.html">
        <input class="form-control mr-sm-2" type="search" name="q" placeholder="Search" aria-label="Search">
        <!-- <button class="btn btn-outline-success my-2 my-sm-0" type="submit">Search</button> -->
      </form>

      <ul class="navbar-nav mr-auto">
        <li class="nav-item <?= isactive("home") ?>">
          <a class="nav-link" href="index.html">Home</a>
        </li>

        <li class="nav-item <?= isactive("about") ?>">
          <a class="nav-link" href="about.html">About</a>
        </li>
      </ul>
    </div>
  </div>
</nav>