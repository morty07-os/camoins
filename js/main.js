/* RITEDJ DECO - Interactions */
document.addEventListener("DOMContentLoaded", function () {
  /* Menu mobile */
  var burger = document.getElementById("burger");
  var menu = document.getElementById("menu");
  if (burger && menu) {
    burger.addEventListener("click", function () {
      menu.classList.toggle("ouvert");
    });
  }

  /* Rendu de la grille produits */
  var grille = document.getElementById("grille-produits");
  var filtres = document.querySelectorAll(".filtre");
  var recherche = document.getElementById("recherche");
  var vide = document.getElementById("aucun-resultat");

  function render(filter, query) {
    if (!grille) return;
    query = (query || "").toLowerCase().trim();
    var items = PRODUCTS.filter(function (p) {
      var okCategorie = filter === "tout" || p.categorieKey === filter;
      var okTexte = !query ||
        p.nom.toLowerCase().indexOf(query) > -1 ||
        p.categorie.toLowerCase().indexOf(query) > -1 ||
        p.accroche.toLowerCase().indexOf(query) > -1;
      return okCategorie && okTexte;
    });

    if (!items.length) {
      grille.innerHTML = "";
      if (vide) vide.style.display = "block";
      return;
    }
    if (vide) vide.style.display = "none";

    grille.innerHTML = items.map(function (p) {
      return '<article class="carte-prod">' +
        '<a class="img" href="produit/' + p.id + '.html"><img src="' + p.image + '" alt="' + p.nom + ' - RITEDJ DECO"></a>' +
        '<div class="corps">' +
        '<span class="cat">' + p.categorie + '</span>' +
        '<h3>' + p.nom + '</h3>' +
        '<p>' + p.accroche + '</p>' +
        '<a class="btn btn-vert" href="produit/' + p.id + '.html">Voir le produit</a>' +
        '</div></article>';
    }).join("");
  }

  var filtreActif = "tout";
  filtres.forEach(function (b) {
    b.addEventListener("click", function () {
      filtres.forEach(function (x) { x.classList.remove("actif"); });
      b.classList.add("actif");
      filtreActif = b.dataset.filtre;
      render(filtreActif, recherche ? recherche.value : "");
    });
  });
  if (recherche) {
    recherche.addEventListener("input", function () {
      render(filtreActif, recherche.value);
    });
  }
  render("tout", "");

  /* Formulaire de contact */
  var formulaire = document.getElementById("form-contact");
  if (formulaire) {
    formulaire.addEventListener("submit", function (e) {
      e.preventDefault();
      var alerte = document.getElementById("alerte");
      if (alerte) {
        alerte.style.display = "block";
        alerte.textContent = "Merci ! Votre demande a bien été envoyée. Notre équipe vous recontacte rapidement.";
      }
      formulaire.reset();
      setTimeout(function () { if (alerte) alerte.style.display = "none"; }, 6000);
    });
  }

  /* Année du pied de page */
  var annee = document.getElementById("annee");
  if (annee) annee.textContent = new Date().getFullYear();
});
