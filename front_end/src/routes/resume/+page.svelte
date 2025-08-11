<script lang="ts">
    const pdfUrl: string = '/api/resume.pdf';
  </script>

  <div class="pdf-container">
    <embed
      src={pdfUrl}
      type="application/pdf"
      width="100%"
      height="100%"
    />
  </div>

  <style>
    .pdf-container {
      width: 100%;
      height: 90vh;  /* Takes up 90% of the viewport height */
    }
  </style>