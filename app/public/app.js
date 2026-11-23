$(function () {
  const fmt = x => Number(x).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const esc = s => $('<div>').text(s).html();

  function loadHistory() {
    $.getJSON('/api/history').done(function (rows) {
      const body = $('#historyBody').empty();
      if (!rows.length) {
        body.append('<tr><td colspan="6" class="text-center text-muted">No calculations yet</td></tr>');
        return;
      }
      rows.forEach(r => body.append(
        `<tr><td>${esc(new Date(r.createdAt).toLocaleString())}</td><td>${fmt(r.principal)}</td>` +
        `<td>${esc(r.rate)}</td><td>${esc(r.months)}</td><td>${fmt(r.emi)}</td><td>${esc(r.servedBy)}</td></tr>`));
    });
  }

  function validate() {
    let ok = true;
    const P = parseFloat($('#P').val()), rate = parseFloat($('#rate').val()), n = Number($('#n').val());
    const checks = [['#P', P > 0], ['#rate', rate > 0], ['#n', Number.isInteger(n) && n > 0]];
    checks.forEach(([sel, valid]) => { $(sel).toggleClass('is-invalid', !valid); if (!valid) ok = false; });
    return ok ? { P, rate, n } : null;
  }

  $('#emiForm').on('submit', function (e) {
    e.preventDefault();                       // no postback
    const data = validate();
    if (!data) return;
    $.ajax({
      url: '/api/emi', method: 'POST', contentType: 'application/json',
      data: JSON.stringify(data)
    }).done(function (res) {
      $('#resultBody').removeClass('text-muted').html(
        `<div class="row text-center">
           <div class="col"><div class="small text-muted">Monthly EMI</div><div class="fs-4 fw-bold">${fmt(res.emi)}</div></div>
           <div class="col"><div class="small text-muted">Total payment</div><div class="fs-5">${fmt(res.totalPayment)}</div></div>
           <div class="col"><div class="small text-muted">Total interest</div><div class="fs-5">${fmt(res.totalInterest)}</div></div>
         </div>
         <hr><div class="small text-muted">Served by pod <b>${esc(res.servedBy)}</b> (${esc(res.podIp)})</div>`);
      loadHistory();
    }).fail(function (xhr) {
      const msg = (xhr.responseJSON && xhr.responseJSON.error) || 'Request failed';
      $('#resultBody').removeClass('text-muted').html(`<div class="text-danger">${esc(msg)}</div>`);
    });
  });

  loadHistory();
});
